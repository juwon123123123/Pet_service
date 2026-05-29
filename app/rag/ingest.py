"""
지식 문서를 ChromaDB에 적재.

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
from app.db.vector_store import get_collection, reset_collection

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n(.*)$", re.DOTALL)


def parse_doc(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    m = FRONTMATTER_RE.match(text)
    if not m:
        raise ValueError(f"{path}: missing YAML frontmatter")
    meta = yaml.safe_load(m.group(1)) or {}
    body = m.group(2).strip()
    return meta, body


def _normalize_meta(meta: dict[str, Any]) -> dict[str, Any]:
    # ChromaDB는 scalar(str/int/float/bool)만 허용
    out: dict[str, Any] = {}
    for k, v in meta.items():
        if v is None:
            continue
        if isinstance(v, (list, dict)):
            out[k] = ",".join(map(str, v)) if isinstance(v, list) else str(v)
        else:
            out[k] = v
    return out


def ingest_dir(knowledge_dir: str | None = None, reset: bool = True) -> int:
    knowledge_dir = knowledge_dir or settings.knowledge_dir
    coll = reset_collection() if reset else get_collection()

    ids, docs, metas = [], [], []
    for root, _, files in os.walk(knowledge_dir):
        for fn in files:
            if not fn.endswith(".md"):
                continue
            meta, body = parse_doc(Path(root) / fn)
            if "id" not in meta:
                raise ValueError(f"{fn}: missing id")
            meta.setdefault("doc_type", "curated")  # 캘린더 변환 대상
            ids.append(str(meta["id"]))
            docs.append(body)
            metas.append(_normalize_meta(meta))

    if not ids:
        return 0
    coll.add(ids=ids, documents=docs, metadatas=metas)
    return len(ids)
