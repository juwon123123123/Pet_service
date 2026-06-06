from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.db.database import init_db
from app.routers import pets, guides, calendar, products, generations

app = FastAPI(title="PET TIMES", description="초보 반려인을 위한 RAG 가이드 + 캘린더 + AI 피팅 쇼핑")


@app.on_event("startup")
def _startup():
    init_db()
    # local 백엔드에서는 업로드 디렉터리 미리 생성 (GCS면 불필요).
    if settings.storage_backend.lower() == "local":
        for sub in ("products", "pet_photos", "generated"):
            (Path(settings.uploads_dir) / sub).mkdir(parents=True, exist_ok=True)


@app.get("/")
def root():
    return {"service": "PET TIMES API", "docs": "/docs", "health": "/health"}


@app.get("/health")
def health():
    return {"ok": True}


app.include_router(pets.router)
app.include_router(guides.router)
app.include_router(calendar.router)
app.include_router(products.router)
app.include_router(generations.router)

# 정적 파일 마운트 — local 백엔드일 때만 업로드 파일을 직접 서빙.
# GCS 백엔드는 버킷이 직접 서빙하므로 /uploads 경로가 필요 없음.
if settings.storage_backend.lower() == "local":
    UPLOADS_DIR = Path(settings.uploads_dir).resolve()
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")
