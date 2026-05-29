from datetime import date, datetime
from typing import Literal, Optional
from pydantic import BaseModel, Field

Species = Literal["dog", "cat"]
Sex = Literal["male", "female"]


class PetCreate(BaseModel):
    name: str
    species: Species
    breed: Optional[str] = None
    birth_date: date
    sex: Sex
    neutered: bool = False
    weight_kg: Optional[float] = None


class PetOut(PetCreate):
    id: int
    age_weeks: int
    age_months: float
    photo_url: Optional[str] = None  # 클라이언트가 즉시 사용 가능한 URL


class PetUpdate(BaseModel):
    name: Optional[str] = None
    breed: Optional[str] = None
    birth_date: Optional[date] = None
    sex: Optional[Sex] = None
    neutered: Optional[bool] = None
    weight_kg: Optional[float] = None


# ── Products / Recommendation / Generation ───────────────────────────────

ProductSpecies = Literal["dog", "cat", "both"]


class ProductOut(BaseModel):
    id: int
    name: str
    species: str
    category: str
    price: int
    image_url: str
    tags: list[str] = []
    size_min_kg: Optional[float] = None
    size_max_kg: Optional[float] = None


class ProductCreate(BaseModel):
    name: str
    species: ProductSpecies
    category: str
    price: int
    image_path: str           # uploads/products/<file> (사용자가 사진 넣은 후 경로)
    tags: Optional[list[str]] = None
    size_min_kg: Optional[float] = None
    size_max_kg: Optional[float] = None


class RecommendOut(BaseModel):
    pet_id: int
    products: list[ProductOut]
    scores: list[float]


class GenerationOut(BaseModel):
    id: int
    pet_id: int
    product_id: int
    source_photo_url: str
    result_url: Optional[str] = None
    status: str
    error: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None


class GenerationRequest(BaseModel):
    pet_id: int
    # 클라이언트가 어떤 사진을 쓸지: 등록한 펫 사진(use_registered=True) 또는 새로 업로드한 임시 사진(temp_photo_path).
    use_registered: bool = True
    temp_photo_path: Optional[str] = None
    # 자동 추천 사용 시 product_ids는 비워두고, 명시적 상품 지정 시 채움.
    product_ids: Optional[list[int]] = None


class GuideRequest(BaseModel):
    pet_id: int
    topics: Optional[list[str]] = Field(
        default=None,
        description="제한할 주제. None이면 펫 상태에 맞는 전반 가이드.",
    )


class Citation(BaseModel):
    doc_id: str
    title: str
    category: str
    source: Optional[str] = None    # e.g. "WSAVA 2024", "AAHA 2022"
    year: Optional[int] = None
    page: Optional[int] = None      # PDF 출처일 때 페이지
    doc_type: Optional[str] = None  # "curated" | "guideline"


class GuideOut(BaseModel):
    pet_id: int
    summary: str
    sections: list[dict]
    citations: list[Citation]
    generated_at: datetime


class EventOut(BaseModel):
    id: int
    pet_id: int
    title: str
    category: str
    due_date: date
    recurring: bool
    interval_days: Optional[int]
    source_doc_id: str
    notes: Optional[str]
    done: bool


class EventCreate(BaseModel):
    title: str
    category: str = "other"
    due_date: date
    recurring: bool = False
    interval_days: Optional[int] = None
    notes: Optional[str] = None


class EventUpdate(BaseModel):
    title: Optional[str] = None
    category: Optional[str] = None
    due_date: Optional[date] = None
    recurring: Optional[bool] = None
    interval_days: Optional[int] = None
    notes: Optional[str] = None
    done: Optional[bool] = None
