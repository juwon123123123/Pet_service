import secrets
from datetime import date
from typing import List

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.db.database import Pet, get_db
from app.models.schemas import PetCreate, PetOut, PetUpdate
from app.scheduler.converter import compute_age
from app.storage import storage

router = APIRouter(prefix="/pets", tags=["pets"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
EXT_BY_TYPE = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def _to_out(p: Pet) -> PetOut:
    weeks, months = compute_age(p.birth_date, date.today())
    return PetOut(
        id=p.id, name=p.name, species=p.species, breed=p.breed,
        birth_date=p.birth_date, sex=p.sex, neutered=p.neutered,
        weight_kg=p.weight_kg, age_weeks=weeks, age_months=months,
        photo_url=(storage.url(p.photo_path) if p.photo_path else None),
    )


@router.post("", response_model=PetOut)
def create_pet(payload: PetCreate, db: Session = Depends(get_db)):
    pet = Pet(**payload.model_dump())
    db.add(pet); db.commit(); db.refresh(pet)
    return _to_out(pet)


@router.get("", response_model=List[PetOut])
def list_pets(db: Session = Depends(get_db)):
    return [_to_out(p) for p in db.query(Pet).all()]


@router.get("/{pet_id}", response_model=PetOut)
def get_pet(pet_id: int, db: Session = Depends(get_db)):
    p = db.get(Pet, pet_id)
    if not p:
        raise HTTPException(404, "pet not found")
    return _to_out(p)


@router.patch("/{pet_id}", response_model=PetOut)
def update_pet(pet_id: int, payload: PetUpdate, db: Session = Depends(get_db)):
    p = db.get(Pet, pet_id)
    if not p:
        raise HTTPException(404, "pet not found")
    data = payload.model_dump(exclude_unset=True)
    for k, v in data.items():
        setattr(p, k, v)
    db.commit(); db.refresh(p)
    return _to_out(p)


@router.delete("/{pet_id}")
def delete_pet(pet_id: int, db: Session = Depends(get_db)):
    p = db.get(Pet, pet_id)
    if not p:
        raise HTTPException(404, "pet not found")
    if p.photo_path:
        storage.delete(p.photo_path)
    db.delete(p); db.commit()
    return {"ok": True}


@router.post("/{pet_id}/photo", response_model=PetOut)
def upload_pet_photo(
    pet_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    p = db.get(Pet, pet_id)
    if not p:
        raise HTTPException(404, "pet not found")
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(400, f"unsupported content_type: {file.content_type}")

    data = file.file.read()
    if len(data) == 0:
        raise HTTPException(400, "empty file")
    if len(data) > 8 * 1024 * 1024:
        raise HTTPException(400, "file too large (max 8MB)")

    ext = EXT_BY_TYPE[file.content_type]
    key = f"uploads/pet_photos/pet_{pet_id}_{secrets.token_hex(6)}.{ext}"
    storage.save(key, data, file.content_type)

    # 이전 사진 정리
    if p.photo_path:
        storage.delete(p.photo_path)

    p.photo_path = key
    db.commit(); db.refresh(p)
    return _to_out(p)
