import json
from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import Pet, Guide, get_db
from app.models.schemas import GuideRequest, GuideOut, Citation
from app.rag.retriever import search
from app.rag.generator import generate_guide
from app.scheduler.converter import compute_age

router = APIRouter(prefix="/guides", tags=["guides"])


def _build_query(pet: Pet, topics) -> str:
    base = f"{pet.species} {pet.breed or ''} 케어 가이드"
    if topics:
        base += " " + " ".join(topics)
    return base.strip()


@router.post("", response_model=GuideOut)
def create_guide(req: GuideRequest, db: Session = Depends(get_db)):
    pet = db.get(Pet, req.pet_id)
    if not pet:
        raise HTTPException(404, "pet not found")

    weeks, months = compute_age(pet.birth_date, date.today())
    pet_ctx = {
        "name": pet.name, "species": pet.species, "breed": pet.breed,
        "sex": pet.sex, "neutered": pet.neutered, "weight_kg": pet.weight_kg,
        "age_weeks": weeks, "age_months": months,
    }

    chunks = search(
        query=_build_query(pet, req.topics),
        species=pet.species,
        age_weeks=weeks,
        breed=pet.breed,
    )
    if not chunks:
        raise HTTPException(404, "관련 지식 문서를 찾지 못했습니다. 지식베이스를 먼저 적재하세요.")

    data = generate_guide(pet_ctx, chunks, req.topics)

    citations = [
        Citation(
            doc_id=c.doc_id,
            title=str(c.meta.get("title", "")),
            category=str(c.meta.get("category", "")),
            source=c.meta.get("source"),
            year=c.meta.get("year") or None,
            page=c.meta.get("page") or None,
            doc_type=c.meta.get("doc_type"),
        )
        for c in chunks
    ]
    out = GuideOut(
        pet_id=pet.id,
        summary=data["summary"],
        sections=data["sections"],
        citations=citations,
        generated_at=datetime.utcnow(),
    )

    db.add(Guide(
        pet_id=pet.id,
        summary=out.summary,
        body_json=json.dumps(
            {"sections": out.sections, "citations": [c.model_dump() for c in citations]},
            ensure_ascii=False,
        ),
    ))
    db.commit()
    return out


@router.get("/{pet_id}/latest", response_model=GuideOut)
def get_latest_guide(pet_id: int, db: Session = Depends(get_db)):
    g = (
        db.query(Guide)
        .filter(Guide.pet_id == pet_id)
        .order_by(Guide.created_at.desc())
        .first()
    )
    if not g:
        raise HTTPException(404, "no guide yet")
    body = json.loads(g.body_json)
    return GuideOut(
        pet_id=g.pet_id,
        summary=g.summary,
        sections=body.get("sections", []),
        citations=[Citation(**c) for c in body.get("citations", [])],
        generated_at=g.created_at,
    )
