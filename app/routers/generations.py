"""
nano-banana 합성 이미지 생성.

흐름:
  1) 클라이언트가 POST /generations
     - use_registered=True 이면 등록된 펫 사진 사용
     - 직접 사진을 쓸 거면 POST /generations/upload_temp 로 임시 업로드 후 temp_photo_path 전달
     - product_ids 비우면 추천기로 5개 선택, 채우면 그 상품만
  2) 백그라운드로 storage 에서 사진 읽어 nano-banana 호출 → 결과를 storage 에 저장
  3) 클라이언트는 GET /generations?pet_id= 로 폴링하면서 status==done 결과만 표시
"""
from __future__ import annotations

import mimetypes
import secrets
from datetime import datetime
from typing import List

from fastapi import (
    APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, UploadFile,
)
from sqlalchemy.orm import Session

from app.config import settings
from app.db.database import Generation, Pet, Product, SessionLocal, get_db
from app.models.schemas import GenerationOut, GenerationRequest
from app.routers.products import to_out as product_to_out
from app.shopping.nano_banana import generate_composite
from app.shopping.recommender import recommend
from app.storage import storage

router = APIRouter(prefix="/generations", tags=["generations"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
EXT_BY_TYPE = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def _to_out(g: Generation) -> GenerationOut:
    return GenerationOut(
        id=g.id,
        pet_id=g.pet_id,
        product_id=g.product_id,
        source_photo_url=storage.url(g.source_photo_path),
        result_url=(storage.url(g.result_path) if g.result_path else None),
        status=g.status,
        error=g.error,
        created_at=g.created_at,
        completed_at=g.completed_at,
    )


def _guess_mime(key: str) -> str:
    m, _ = mimetypes.guess_type(key)
    return m or "image/jpeg"


@router.post("/upload_temp")
def upload_temp_photo(file: UploadFile = File(...)):
    """추천 이미지 생성 시 등록 사진 대신 즉석에서 올리는 사진."""
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(400, f"unsupported content_type: {file.content_type}")
    data = file.file.read()
    if len(data) == 0:
        raise HTTPException(400, "empty file")
    if len(data) > 8 * 1024 * 1024:
        raise HTTPException(400, "file too large (max 8MB)")

    ext = EXT_BY_TYPE[file.content_type]
    key = f"uploads/pet_photos/temp_{secrets.token_hex(8)}.{ext}"
    storage.save(key, data, file.content_type)
    return {"photo_path": key, "photo_url": storage.url(key)}


def _run_job(gen_id: int):
    """백그라운드 워커. 새 세션을 자체 보유."""
    db = SessionLocal()
    try:
        g = db.get(Generation, gen_id)
        if g is None:
            return
        try:
            pet = db.get(Pet, g.pet_id)
            product = db.get(Product, g.product_id)
            if pet is None or product is None:
                raise RuntimeError("pet/product 사라짐")

            # 두 사진을 storage 에서 읽음 (local: 파일, gcs: blob)
            pet_bytes = storage.read_bytes(g.source_photo_path)
            product_bytes = storage.read_bytes(product.image_path)

            image_bytes = generate_composite(
                pet_photo_bytes=pet_bytes,
                pet_photo_mime=_guess_mime(g.source_photo_path),
                product_photo_bytes=product_bytes,
                product_photo_mime=_guess_mime(product.image_path),
                pet_name=pet.name,
                species=pet.species,
                product_name=product.name,
                category=product.category,
            )
            key = f"uploads/generated/gen_{g.id}_{secrets.token_hex(4)}.png"
            storage.save(key, image_bytes, "image/png")
            g.result_path = key
            g.status = "done"
            g.completed_at = datetime.utcnow()
        except Exception as e:
            g.status = "failed"
            g.error = str(e)[:500]
            g.completed_at = datetime.utcnow()
        db.commit()
    finally:
        db.close()


@router.post("", response_model=List[GenerationOut])
def create_generations(
    req: GenerationRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    pet = db.get(Pet, req.pet_id)
    if pet is None:
        raise HTTPException(404, "pet not found")

    if req.use_registered:
        if not pet.photo_path:
            raise HTTPException(400, "이 펫에 등록된 사진이 없어요. 먼저 사진을 업로드해주세요.")
        source = pet.photo_path
    else:
        if not req.temp_photo_path:
            raise HTTPException(400, "temp_photo_path 가 필요해요. /generations/upload_temp 먼저 호출하세요.")
        if not storage.exists(req.temp_photo_path):
            raise HTTPException(400, f"임시 사진을 찾을 수 없음: {req.temp_photo_path}")
        source = req.temp_photo_path

    if req.product_ids:
        products = (
            db.query(Product)
            .filter(Product.id.in_(req.product_ids), Product.is_active.is_(True))
            .all()
        )
    else:
        candidates = (
            db.query(Product)
            .filter(
                Product.is_active.is_(True),
                Product.species.in_([pet.species, "both"]),
            )
            .all()
        )
        if not candidates:
            raise HTTPException(404, "추천 가능한 상품이 없어요. 먼저 상품을 등록해주세요.")
        scored = recommend(pet, candidates, k=settings.recommend_k)
        products = [s.product for s in scored]

    if not products:
        raise HTTPException(404, "생성할 상품이 없습니다.")

    rows: list[Generation] = []
    for prod in products:
        g = Generation(
            pet_id=pet.id,
            product_id=prod.id,
            source_photo_path=source,
            status="pending",
        )
        db.add(g); rows.append(g)
    db.commit()
    for g in rows: db.refresh(g)

    for g in rows:
        background_tasks.add_task(_run_job, g.id)

    return [_to_out(g) for g in rows]


@router.get("", response_model=List[GenerationOut])
def list_generations(
    pet_id: int = Query(...),
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Generation)
        .filter(Generation.pet_id == pet_id)
        .order_by(Generation.created_at.desc())
        .limit(limit)
        .all()
    )
    return [_to_out(g) for g in rows]


@router.get("/{gen_id}", response_model=GenerationOut)
def get_generation(gen_id: int, db: Session = Depends(get_db)):
    g = db.get(Generation, gen_id)
    if not g:
        raise HTTPException(404, "generation not found")
    return _to_out(g)


@router.delete("/{gen_id}")
def delete_generation(gen_id: int, db: Session = Depends(get_db)):
    g = db.get(Generation, gen_id)
    if not g:
        raise HTTPException(404, "generation not found")
    if g.result_path:
        storage.delete(g.result_path)
    db.delete(g); db.commit()
    return {"ok": True}


@router.get("/recommend/{pet_id}")
def recommend_only(pet_id: int, db: Session = Depends(get_db)):
    pet = db.get(Pet, pet_id)
    if pet is None:
        raise HTTPException(404, "pet not found")
    candidates = (
        db.query(Product)
        .filter(
            Product.is_active.is_(True),
            Product.species.in_([pet.species, "both"]),
        )
        .all()
    )
    scored = recommend(pet, candidates, k=settings.recommend_k)
    return {
        "pet_id": pet_id,
        "products": [product_to_out(s.product).model_dump() for s in scored],
        "scores": [round(s.score, 3) for s in scored],
    }
