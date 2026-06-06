from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Date, Boolean, Float, DateTime, ForeignKey, Text,
    create_engine,
)
from sqlalchemy.orm import declarative_base, sessionmaker, relationship

from app.config import settings

# pgvector는 Postgres 백엔드에서만 의미가 있으므로 지연 import.
def _vector_column(dim: int):
    """pgvector Vector 컬럼. SQLite 등 다른 백엔드에서는 fallback으로 Text 저장."""
    if settings.database_url.startswith("postgresql"):
        from pgvector.sqlalchemy import Vector
        return Vector(dim)
    return Text  # SQLite 폴백 — 사실상 RAG는 Postgres 전용이지만 import만 깨지지 않게.

engine = create_engine(
    settings.database_url,
    connect_args={"check_same_thread": False} if settings.database_url.startswith("sqlite") else {},
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()


class Pet(Base):
    __tablename__ = "pets"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    species = Column(String, nullable=False)  # dog | cat
    breed = Column(String, nullable=True)
    birth_date = Column(Date, nullable=False)
    sex = Column(String, nullable=False)  # male | female
    neutered = Column(Boolean, default=False)
    weight_kg = Column(Float, nullable=True)
    photo_path = Column(String, nullable=True)  # uploads/pet_photos/<file>
    created_at = Column(DateTime, default=datetime.utcnow)

    events = relationship("Event", back_populates="pet", cascade="all, delete-orphan")
    guides = relationship("Guide", back_populates="pet", cascade="all, delete-orphan")
    generations = relationship("Generation", back_populates="pet", cascade="all, delete-orphan")


class Event(Base):
    __tablename__ = "events"
    id = Column(Integer, primary_key=True)
    pet_id = Column(Integer, ForeignKey("pets.id"), nullable=False)
    title = Column(String, nullable=False)
    category = Column(String, nullable=False)
    due_date = Column(Date, nullable=False)
    recurring = Column(Boolean, default=False)
    interval_days = Column(Integer, nullable=True)
    source_doc_id = Column(String, nullable=False)
    notes = Column(Text, nullable=True)
    done = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    pet = relationship("Pet", back_populates="events")


class Guide(Base):
    __tablename__ = "guides"
    id = Column(Integer, primary_key=True)
    pet_id = Column(Integer, ForeignKey("pets.id"), nullable=False)
    summary = Column(Text, nullable=False)
    body_json = Column(Text, nullable=False)  # serialized sections + citations
    created_at = Column(DateTime, default=datetime.utcnow)

    pet = relationship("Pet", back_populates="guides")


class Product(Base):
    """가짜 쇼핑몰 상품. 사진은 ./uploads/products/ 아래."""
    __tablename__ = "products"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    species = Column(String, nullable=False)  # dog | cat | both
    category = Column(String, nullable=False)  # 옷 / 하네스 / 장난감 / 액세서리 등
    price = Column(Integer, nullable=False)    # 원 단위 정수
    image_path = Column(String, nullable=False)  # uploads/products/<file>
    # 추천 점수 계산용 메타. comma-separated 자유 키워드.
    tags = Column(String, nullable=True)         # 예: "겨울,방수,실내"
    # 사이즈 매칭 (펫 체중 기준). nullable이면 무시.
    size_min_kg = Column(Float, nullable=True)
    size_max_kg = Column(Float, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Generation(Base):
    """nano-banana 이미지 생성 job. pending → done/failed."""
    __tablename__ = "generations"
    id = Column(Integer, primary_key=True)
    pet_id = Column(Integer, ForeignKey("pets.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    source_photo_path = Column(String, nullable=False)  # 합성에 쓴 펫 사진
    result_path = Column(String, nullable=True)         # 생성된 결과 이미지 경로
    status = Column(String, nullable=False, default="pending")  # pending/done/failed
    error = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)

    pet = relationship("Pet", back_populates="generations")
    product = relationship("Product")


class KnowledgeChunk(Base):
    """RAG 검색용 청크 (큐레이션 .md + 공식 가이드라인 PDF 페이지).

    embedding 컬럼은 pgvector(384) — sentence-transformers MiniLM 출력 차원.
    SQLite에선 의미 없음 (실제 RAG는 Postgres에서만 동작).
    """
    __tablename__ = "knowledge_chunks"

    id = Column(String, primary_key=True)             # chunk ID (doc_id + 페이지/청크 인덱스)
    doc_id = Column(String, nullable=False, index=True)
    text = Column(Text, nullable=False)
    doc_type = Column(String, nullable=False, index=True)  # curated | guideline

    species = Column(String, nullable=False, index=True)   # dog | cat | both
    category = Column(String, nullable=True)
    title = Column(String, nullable=True)
    source = Column(String, nullable=True)
    year = Column(Integer, nullable=True)
    page = Column(Integer, nullable=True)
    priority = Column(String, nullable=True)               # low | normal | high
    breed = Column(String, nullable=True)
    file = Column(String, nullable=True)

    # 캘린더 스케줄링 메타 (curated만 채움)
    age_min_weeks = Column(Integer, nullable=True)
    age_max_weeks = Column(Integer, nullable=True)
    recurring = Column(Boolean, nullable=True)
    interval_days = Column(Integer, nullable=True)
    start_age_weeks = Column(Integer, nullable=True)
    end_age_weeks = Column(Integer, nullable=True)

    embedding = Column(_vector_column(384), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    def to_meta(self) -> dict:
        """기존 ChromaDB metadata 형식과 호환되는 dict 반환."""
        out = {
            "doc_type": self.doc_type,
            "species": self.species,
            "category": self.category,
            "title": self.title,
            "source": self.source,
            "year": self.year,
            "page": self.page,
            "priority": self.priority,
            "breed": self.breed,
            "file": self.file,
            "age_min_weeks": self.age_min_weeks,
            "age_max_weeks": self.age_max_weeks,
            "recurring": self.recurring,
            "interval_days": self.interval_days,
            "start_age_weeks": self.start_age_weeks,
            "end_age_weeks": self.end_age_weeks,
        }
        return {k: v for k, v in out.items() if v is not None}


def _ensure_pgvector_extension():
    """Postgres라면 CREATE EXTENSION vector. SQLite면 no-op."""
    if not settings.database_url.startswith("postgresql"):
        return
    from sqlalchemy import text
    with engine.begin() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))


def _migrate_pet_photo_path():
    """레거시 DB(이전 버전에서 만든 pets 테이블)에 photo_path 가 없으면 추가.
    SQLite와 Postgres 모두 ALTER TABLE 같은 문법으로 동작."""
    from sqlalchemy import inspect, text
    insp = inspect(engine)
    if "pets" not in insp.get_table_names():
        return
    cols = {c["name"] for c in insp.get_columns("pets")}
    if "photo_path" not in cols:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE pets ADD COLUMN photo_path VARCHAR"))


def init_db():
    # pgvector extension은 테이블 생성 전에 활성화돼야 Vector(384) 컬럼 만들 수 있음.
    _ensure_pgvector_extension()
    Base.metadata.create_all(bind=engine)
    _migrate_pet_photo_path()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
