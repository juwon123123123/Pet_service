from __future__ import annotations
"""
공식 가이드라인 PDF -> ChromaDB.

- 페이지 단위로 텍스트를 추출하고 ~900자 청크(100자 오버랩)로 분할
- 각 청크는 매니페스트의 메타데이터 + page 번호를 함께 저장
- doc_type=guideline 플래그로 캘린더 변환기에서 제외됨 (스케줄링은 .md 시드 전용)
"""

from pathlib import Path
from typing import Iterator

import yaml
from pypdf import PdfReader

from app.config import settings
from app.db.vector_store import get_collection

CHUNK_SIZE = 900
CHUNK_OVERLAP = 100


def _chunk_text(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> Iterator[str]:
    text = " ".join(text.split())
    if not text:
        return
    start = 0
    while start < len(text):
        end = min(start + size, len(text))
        yield text[start:end]
        if end >= len(text):
            break
        start = end - overlap


def _slug(s: str) -> str:
    return "".join(c if c.isalnum() else "_" for c in s.lower())


def ingest_pdf(pdf_path: Path, entry: dict) -> int:
    reader = PdfReader(str(pdf_path))
    base_id = _slug(pdf_path.stem)

    ids, docs, metas = [], [], []
    for page_idx, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        for chunk_idx, chunk in enumerate(_chunk_text(text)):
            if len(chunk) < 80:
                continue
            ids.append(f"{base_id}_p{page_idx}_c{chunk_idx}")
            docs.append(chunk)
            metas.append({
                "doc_type": "guideline",
                "source": str(entry.get("source", "")),
                "year": int(entry.get("year", 0)) if entry.get("year") else 0,
                "title": str(entry.get("title", pdf_path.stem)),
                "species": str(entry.get("species", "both")),
                "category": str(entry.get("category", "general")),
                "priority": str(entry.get("priority", "normal")),
                "page": page_idx,
                "file": pdf_path.name,
            })

    if not ids:
        return 0
    coll = get_collection()
    coll.add(ids=ids, documents=docs, metadatas=metas)
    return len(ids)


def ingest_manifest(sources_dir: str | None = None) -> dict:
    sources_dir = Path(sources_dir or "app/data/sources")
    manifest = sources_dir / "manifest.yaml"
    if not manifest.exists():
        return {"loaded": 0, "files": [], "skipped": [], "note": "manifest.yaml 없음 - PDF 적재 생략"}

    spec = yaml.safe_load(manifest.read_text(encoding="utf-8")) or {}
    entries = spec.get("sources", [])

    total, loaded_files, skipped = 0, [], []
    for entry in entries:
        fn = entry.get("file")
        if not fn:
            continue
        path = sources_dir / fn
        if not path.exists():
            skipped.append(fn)
            continue
        n = ingest_pdf(path, entry)
        total += n
        loaded_files.append({"file": fn, "chunks": n, "source": entry.get("source")})

    return {"loaded": total, "files": loaded_files, "skipped": skipped}
