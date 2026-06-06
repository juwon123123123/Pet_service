"""
상품 (가짜 쇼핑몰).
- GET  /products
- GET  /products/{id}
- POST /products
- POST /products/upload_image  (사진 먼저 올리고 키 받는 흐름)
"""
from __future__ import annotations

import secrets
from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session

from app.db.database import Product, get_db
from app.models.schemas import ProductCreate, ProductOut
from app.storage import storage

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
        image_url=storage.url(p.image_path) if p.image_path else "",
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
    """상품 등록 전 사진을 먼저 업로드해서 image_path(저장소 키)를 받는다."""
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(400, f"unsupported content_type: {file.content_type}")
    data = file.file.read()
    if len(data) == 0:
        raise HTTPException(400, "empty file")
    ext = EXT_BY_TYPE[file.content_type]
    key = f"uploads/products/product_{secrets.token_hex(8)}.{ext}"
    storage.save(key, data, file.content_type)
    return {"image_path": key, "image_url": storage.url(key)}


@router.post("", response_model=ProductOut)
def create_product(payload: ProductCreate, db: Session = Depends(get_db)):
    if not storage.exists(payload.image_path):
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
    p.is_active = False  # soft delete (이미지 파일은 보존)
    db.commit()
    return {"ok": True}
