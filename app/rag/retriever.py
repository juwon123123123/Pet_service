"""
pgvector 기반 검색 + 메타데이터 필터 + 휴리스틱 재순위.

재순위 규칙(휴리스틱, 외부 모델 없이):
  - 종 일치(+0.35)
  - 펫 연령(주)이 age_min_weeks ~ age_max_weeks 범위 안 (+0.55)
  - 범위 밖이지만 12주 이내로 인접 (+0.20)
  - priority=high (+0.1)

Postgres pgvector 가 코사인 거리(`<=>`)로 1차 회수 → Python에서 위 가중치 합산 후 재정렬.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.db.database import KnowledgeChunk, SessionLocal
from app.db.vector_store import embed_one


@dataclass
class RetrievedChunk:
    doc_id: str
    text: str
    meta: dict[str, Any]
    score: float


def _rerank_score(base: float, chunk: KnowledgeChunk, species: str,
                  age_weeks: int) -> float:
    bonus = 0.0

    # 종 일치 — 종이 다른 케어 정보는 의미가 없으므로 강하게 가산.
    if chunk.species == species:
        bonus += 0.35

    # 나이 — 반려동물 케어에서 가장 결정적. 범위 적중에 최대 가중치.
    if chunk.age_min_weeks is not None and chunk.age_max_weeks is not None:
        amin, amax = chunk.age_min_weeks, chunk.age_max_weeks
        if amin <= age_weeks <= amax:
            bonus += 0.55
        else:
            gap = min(abs(age_weeks - amin), abs(age_weeks - amax))
            if gap <= 12:
                bonus += 0.20

    if chunk.priority == "high":
        bonus += 0.1

    return base + bonus


def _to_retrieved(chunk: KnowledgeChunk, score: float) -> RetrievedChunk:
    return RetrievedChunk(
        doc_id=chunk.doc_id,
        text=chunk.text,
        meta=chunk.to_meta(),
        score=score,
    )


def search(
    query: str,
    species: str,
    age_weeks: int,
    top_k: int | None = None,
    pool_k: int = 20,
) -> list[RetrievedChunk]:
    top_k = top_k or settings.top_k
    query_vec = embed_one(query)

    db: Session = SessionLocal()
    try:
        # pgvector 코사인 거리: `embedding <=> :vec` (0=동일, 2=정반대)
        # SQLAlchemy로 ORDER BY 표현. pgvector 패키지가 연산자를 자동 등록.
        stmt = (
            select(KnowledgeChunk,
                   KnowledgeChunk.embedding.cosine_distance(query_vec).label("dist"))
            .where(KnowledgeChunk.species.in_([species, "both"]))
            .order_by(KnowledgeChunk.embedding.cosine_distance(query_vec))
            .limit(pool_k)
        )
        results = db.execute(stmt).all()
    finally:
        db.close()

    scored: list[RetrievedChunk] = []
    for chunk, dist in results:
        base = 1.0 - float(dist)  # 코사인 distance → similarity
        score = _rerank_score(base, chunk, species, age_weeks)
        scored.append(_to_retrieved(chunk, score))

    scored.sort(key=lambda c: c.score, reverse=True)
    return scored[:top_k]


def all_relevant_for_schedule(species: str, age_weeks: int) -> list[RetrievedChunk]:
    """
    캘린더 변환용. 종 일치 + schedule 메타가 있는 청크 전부 회수.
    age_weeks는 인터페이스 호환을 위해 받음 (현재 로직에선 미사용).
    """
    _ = age_weeks  # 미사용 의도 명시
    db: Session = SessionLocal()
    try:
        # one-shot: age_min/max 둘 다 있어야 함
        # recurring: 그냥 True
        rows = (
            db.query(KnowledgeChunk)
            .filter(KnowledgeChunk.species.in_([species, "both"]))
            .filter(
                (
                    (KnowledgeChunk.age_min_weeks.isnot(None))
                    & (KnowledgeChunk.age_max_weeks.isnot(None))
                )
                | (KnowledgeChunk.recurring.is_(True))
            )
            .all()
        )
    finally:
        db.close()
    return [_to_retrieved(c, 1.0) for c in rows]
