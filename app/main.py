from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.db.database import init_db
from app.routers import pets, guides, calendar, products, generations

app = FastAPI(title="Pet AI", description="초보 반려인을 위한 RAG 기반 가이드 + 캘린더 + 쇼핑 추천")


@app.on_event("startup")
def _startup():
    init_db()
    # 업로드 디렉터리 보장
    for sub in ("products", "pet_photos", "generated"):
        (Path(settings.uploads_dir) / sub).mkdir(parents=True, exist_ok=True)


@app.get("/health")
def health():
    return {"ok": True}


app.include_router(pets.router)
app.include_router(guides.router)
app.include_router(calendar.router)
app.include_router(products.router)
app.include_router(generations.router)

# 정적 파일 마운트
UPLOADS_DIR = Path(settings.uploads_dir).resolve()
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

WEB_DIR = Path(__file__).parent / "web"
app.mount("/web", StaticFiles(directory=WEB_DIR), name="web")


@app.get("/", include_in_schema=False)
def index():
    return FileResponse(WEB_DIR / "index.html")
