"""
pgvector 기반 지식 청크 저장소.

- 임베딩: sentence-transformers `paraphrase-multilingual-MiniLM-L12-v2` (384-dim)
- 저장: Postgres `knowledge_chunks` 테이블의 `embedding` 컬럼 (pgvector)
- 검색은 `app/rag/retriever.py` 가 수행 (코사인 거리 `<=>`).

이 모듈은 (1) 임베딩 모델 캐시 (2) 청크 batch insert (3) reset 헬퍼 제공.
"""
from __future__ import annotations

from functools import lru_cache
from typing import Any, Iterable

from sentence_transformers import SentenceTransformer
from sqlalchemy import text

from app.config import settings
from app.db.database import KnowledgeChunk, SessionLocal, engine


@lru_cache(maxsize=1)
def get_embedder() -> SentenceTransformer:
    """모델 1회 로드, 이후 캐시. CPU에서 동작 (콜드스타트 1~3초)."""
    return SentenceTransformer(settings.embed_model)


def embed_texts(texts: list[str]) -> list[list[float]]:
    """문자열 리스트 → 384차원 벡터 리스트."""
    model = get_embedder()
    arr = model.encode(texts, batch_size=32, show_progress_bar=False, convert_to_numpy=True)
    return arr.tolist()


def embed_one(text_in: str) -> list[float]:
    return embed_texts([text_in])[0]


# ── 데이터 적재 ────────────────────────────────────────────────

def insert_chunks(rows: Iterable[dict[str, Any]]) -> int:
    """rows: 각 항목은 KnowledgeChunk 컬럼명을 key로 가진 dict.
    `text` 키가 필수이며, embedding이 없으면 자동 계산."""
    rows = list(rows)
    if not rows:
        return 0

    # 임베딩 누락된 것만 일괄 계산 (배치)
    missing_idx = [i for i, r in enumerate(rows) if not r.get("embedding")]
    if missing_idx:
        vectors = embed_texts([rows[i]["text"] for i in missing_idx])
        for j, i in enumerate(missing_idx):
            rows[i]["embedding"] = vectors[j]

    db = SessionLocal()
    try:
        objs = [KnowledgeChunk(**r) for r in rows]
        db.add_all(objs)
        db.commit()
        return len(objs)
    finally:
        db.close()


def reset_all() -> None:
    """모든 청크 삭제 (시드 재실행 시)."""
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM knowledge_chunks"))


def count_chunks() -> int:
    with engine.connect() as conn:
        return conn.execute(text("SELECT COUNT(*) FROM knowledge_chunks")).scalar() or 0
