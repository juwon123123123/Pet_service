"""
상품 (가짜 쇼핑몰).
- GET /products?species=&category= 목록
- POST /products 상품 등록 (운영자 / 시드 스크립트용)
- POST /products/upload_image: 상품 사진 업로드 (multipart). 등록 전 사진 먼저 올리고 경로를 받는 흐름.
"""
from __future__ import annotations

import secrets
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session

from app.config import settings
from app.db.database import Product, get_db
from app.models.schemas import ProductCreate, ProductOut

router = APIRouter(prefix="/products", tags=["products"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
EXT_BY_TYPE = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def to_out(p: Product) -> ProductOut:
    return ProductOut(
        id=p.id,
        name=p.name,
        species=p.species,
        category=p.category,
        price=p.price,
        image_url=f"/{p.image_path}" if p.image_path else "",
        tags=[t.strip() for t in (p.tags or "").split(",") if t.strip()],
        size_min_kg=p.size_min_kg,
        size_max_kg=p.size_max_kg,
    )


@router.get("", response_model=List[ProductOut])
def list_products(
    species: Optional[str] = Query(None, description="dog | cat | both"),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(Product).filter(Product.is_active.is_(True))
    if species:
        # species=dog 이면 dog + both 모두 노출
        q = q.filter(Product.species.in_([species, "both"]))
    if category:
        q = q.filter(Product.category == category)
    return [to_out(p) for p in q.order_by(Product.created_at.desc()).all()]


@router.get("/{product_id}", response_model=ProductOut)
def get_product(product_id: int, db: Session = Depends(get_db)):
    p = db.get(Product, product_id)
    if not p or not p.is_active:
        raise HTTPException(404, "product not found")
    return to_out(p)


@router.post("/upload_image")
def upload_product_image(file: UploadFile = File(...)):
    """상품 등록 전 사진을 먼저 업로드해서 image_path 를 받는다."""
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(400, f"unsupported content_type: {file.content_type}")
    ext = EXT_BY_TYPE[file.content_type]
    fname = f"product_{secrets.token_hex(8)}.{ext}"
    dest_dir = Path(settings.uploads_dir) / "products"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / fname
    data = file.file.read()
    if len(data) == 0:
        raise HTTPException(400, "empty file")
    dest.write_bytes(data)
    rel = str(dest).replace("\\", "/").lstrip("./")
    return {"image_path": rel, "image_url": f"/{rel}"}


@router.post("", response_model=ProductOut)
def create_product(payload: ProductCreate, db: Session = Depends(get_db)):
    # image_path 검증 (실제 파일 존재 확인)
    if not Path(payload.image_path).exists():
        raise HTTPException(400, f"image not found at {payload.image_path}")
    p = Product(
        name=payload.name,
        species=payload.species,
        category=payload.category,
        price=payload.price,
        image_path=payload.image_path,
        tags=",".join(payload.tags) if payload.tags else None,
        size_min_kg=payload.size_min_kg,
        size_max_kg=payload.size_max_kg,
        is_active=True,
    )
    db.add(p); db.commit(); db.refresh(p)
    return to_out(p)


@router.delete("/{product_id}")
def delete_product(product_id: int, db: Session = Depends(get_db)):
    p = db.get(Product, product_id)
    if not p:
        raise HTTPException(404, "product not found")
    p.is_active = False  # soft delete
    db.commit()
    return {"ok": True}
