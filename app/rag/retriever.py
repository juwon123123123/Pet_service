from __future__ import annotations
"""
검색 + 메타데이터 필터 + 경량 재순위.

재순위 규칙(휴리스틱, 외부 모델 없이):
  - 종 일치(+0.25)
  - 펫의 연령(주)이 age_min_weeks ~ age_max_weeks 범위 안 (+0.4)
  - 범위 밖이지만 12주 이내로 인접 (+0.15)
  - priority=high (+0.1)
  - 품종이 명시되어 있고 일치 (+0.15)
"""

from dataclasses import dataclass
from typing import Any, Optional

from app.config import settings
from app.db.vector_store import get_collection


@dataclass
class RetrievedChunk:
    doc_id: str
    text: str
    meta: dict[str, Any]
    score: float


def _passes_species(meta: dict, species: str) -> bool:
    s = str(meta.get("species", "both"))
    return s in (species, "both")


def search(
    query: str,
    species: str,
    age_weeks: int,
    breed: Optional[str] = None,
    top_k: int = None,
    pool_k: int = 20,
) -> list[RetrievedChunk]:
    top_k = top_k or settings.top_k
    coll = get_collection()
    # ChromaDB의 where 절은 단순. 종 필터만 1차로 걸고 후처리에서 재순위.
    res = coll.query(
        query_texts=[query],
        n_results=pool_k,
        where={"species": {"$in": [species, "both"]}},
    )

    chunks: list[RetrievedChunk] = []
    docs = res.get("documents", [[]])[0]
    metas = res.get("metadatas", [[]])[0]
    ids = res.get("ids", [[]])[0]
    dists = res.get("distances", [[]])[0]

    for doc_id, text, meta, dist in zip(ids, docs, metas, dists):
        if not _passes_species(meta, species):
            continue
        base = 1.0 - float(dist)  # cosine distance -> similarity
        bonus = 0.0

        if meta.get("species") == species:
            bonus += 0.25

        amin = meta.get("age_min_weeks")
        amax = meta.get("age_max_weeks")
        if amin is not None and amax is not None:
            if amin <= age_weeks <= amax:
                bonus += 0.4
            else:
                gap = min(abs(age_weeks - amin), abs(age_weeks - amax))
                if gap <= 12:
                    bonus += 0.15

        if meta.get("priority") == "high":
            bonus += 0.1

        if breed and meta.get("breed") and breed.lower() == str(meta["breed"]).lower():
            bonus += 0.15

        chunks.append(RetrievedChunk(doc_id=doc_id, text=text, meta=meta, score=base + bonus))

    chunks.sort(key=lambda c: c.score, reverse=True)
    return chunks[:top_k]


def all_relevant_for_schedule(species: str, age_weeks: int) -> list[RetrievedChunk]:
    """
    캘린더 변환용. 종 일치하면서 schedule 관련 메타가 있는 문서를 메타필터로 모두 회수.
    """
    coll = get_collection()
    res = coll.get(where={"species": {"$in": [species, "both"]}})
    out: list[RetrievedChunk] = []
    for doc_id, text, meta in zip(res["ids"], res["documents"], res["metadatas"]):
        has_oneshot = meta.get("age_min_weeks") is not None and meta.get("age_max_weeks") is not None
        has_recurring = bool(meta.get("recurring"))
        if not (has_oneshot or has_recurring):
            continue
        out.append(RetrievedChunk(doc_id=doc_id, text=text, meta=meta, score=1.0))
    return out
