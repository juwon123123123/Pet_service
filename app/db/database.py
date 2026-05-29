from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Date, Boolean, Float, DateTime, ForeignKey, Text,
    create_engine,
)
from sqlalchemy.orm import declarative_base, sessionmaker, relationship

from app.config import settings

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


def _migrate_pet_photo_path():
    """SQLite ADD COLUMN: 기존 pets 테이블에 photo_path 가 없으면 추가."""
    if not settings.database_url.startswith("sqlite"):
        return
    from sqlalchemy import inspect, text
    insp = inspect(engine)
    if "pets" not in insp.get_table_names():
        return
    cols = {c["name"] for c in insp.get_columns("pets")}
    if "photo_path" not in cols:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE pets ADD COLUMN photo_path VARCHAR"))


def init_db():
    Base.metadata.create_all(bind=engine)
    _migrate_pet_photo_path()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
