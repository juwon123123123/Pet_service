"""
지식 문서를 pgvector(knowledge_chunks 테이블)에 적재.

문서 포맷: YAML 프론트매터를 가진 마크다운.
필수 메타데이터:
  id, species(dog|cat|both), category, title
선택:
  age_min_weeks, age_max_weeks  -> 캘린더 이벤트 1회성으로 변환
  recurring(True/False), interval_days, start_age_weeks, end_age_weeks
  breed (지정 시 그 품종 한정), priority(low|normal|high)
"""
from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

import yaml

from app.config import settings
from app.db.database import KnowledgeChunk, SessionLocal
from app.db.vector_store import insert_chunks

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n(.*)$", re.DOTALL)

# KnowledgeChunk 컬럼 화이트리스트 — 알려진 필드만 dict에 담아 ORM에 넘김.
_ALLOWED_KEYS = {
    "doc_id", "text", "doc_type", "species", "category", "title", "source",
    "year", "page", "priority", "breed", "file",
    "age_min_weeks", "age_max_weeks", "recurring", "interval_days",
    "start_age_weeks", "end_age_weeks",
}


def parse_doc(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    m = FRONTMATTER_RE.match(text)
    if not m:
        raise ValueError(f"{path}: missing YAML frontmatter")
    meta = yaml.safe_load(m.group(1)) or {}
    body = m.group(2).strip()
    return meta, body


def _to_row(meta: dict[str, Any], body: str) -> dict[str, Any]:
    """frontmatter dict → KnowledgeChunk 컬럼 dict."""
    doc_id = str(meta["id"])
    row: dict[str, Any] = {
        "id": doc_id,
        "doc_id": doc_id,
        "text": body,
        "doc_type": meta.get("doc_type", "curated"),
    }
    for k, v in meta.items():
        if k == "id" or v is None:
            continue
        if k in _ALLOWED_KEYS:
            row[k] = v
    # 필수
    row.setdefault("species", "both")
    return row


def ingest_dir(knowledge_dir: str | None = None, reset: bool = True) -> int:
    knowledge_dir = knowledge_dir or settings.knowledge_dir

    if reset:
        # 이 함수에서는 큐레이션 청크만 정리. PDF(guideline)은 보존.
        db = SessionLocal()
        try:
            db.query(KnowledgeChunk).filter(
                KnowledgeChunk.doc_type == "curated"
            ).delete(synchronize_session=False)
            db.commit()
        finally:
            db.close()

    rows: list[dict[str, Any]] = []
    for root, _, files in os.walk(knowledge_dir):
        for fn in files:
            if not fn.endswith(".md"):
                continue
            meta, body = parse_doc(Path(root) / fn)
            if "id" not in meta:
                raise ValueError(f"{fn}: missing id")
            rows.append(_to_row(meta, body))

    return insert_chunks(rows)
