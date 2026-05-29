"""지식베이스(.md 시드 + 공식 가이드라인 PDF)를 ChromaDB에 적재.
Usage:
    python -m scripts.seed_knowledge
"""
from app.rag.ingest import ingest_dir
from app.rag.pdf_ingest import ingest_manifest
from app.db.database import init_db


def main():
    init_db()
    n_md = ingest_dir(reset=True)        # 컬렉션 초기화 후 .md 시드 적재
    print(f"[md] ingested {n_md} curated documents")

    result = ingest_manifest()           # PDF 매니페스트가 있으면 같은 컬렉션에 추가
    print(f"[pdf] ingested {result['loaded']} chunks from {len(result['files'])} file(s)")
    for f in result["files"]:
        print(f"      - {f['file']} ({f['source']}) -> {f['chunks']} chunks")
    if result["skipped"]:
        print(f"[pdf] skipped (file not found): {result['skipped']}")
    if "note" in result:
        print(f"[pdf] {result['note']}")


if __name__ == "__main__":
    main()
