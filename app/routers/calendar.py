from datetime import date, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.database import Pet, Event, get_db
from app.models.schemas import EventOut, EventCreate, EventUpdate
from app.scheduler.converter import build_schedule, compute_age

router = APIRouter(prefix="/calendar", tags=["calendar"])

USER_SOURCE = "user"


def _to_out(e: Event) -> EventOut:
    return EventOut(
        id=e.id, pet_id=e.pet_id, title=e.title, category=e.category,
        due_date=e.due_date, recurring=e.recurring, interval_days=e.interval_days,
        source_doc_id=e.source_doc_id, notes=e.notes, done=e.done,
    )


@router.post("/{pet_id}/rebuild", response_model=List[EventOut])
def rebuild(pet_id: int, horizon_days: int = 365, db: Session = Depends(get_db)):
    pet = db.get(Pet, pet_id)
    if not pet:
        raise HTTPException(404, "pet not found")

    today = date.today()
    weeks, _ = compute_age(pet.birth_date, today)
    planned = build_schedule(pet.birth_date, pet.species, weeks, today, horizon_days)

    # 사용자가 직접 추가한 이벤트는 보존, 시스템 생성분만 정리.
    db.query(Event).filter(
        Event.pet_id == pet_id,
        Event.done.is_(False),
        Event.source_doc_id != USER_SOURCE,
    ).delete()
    db.commit()

    rows = []
    for p in planned:
        e = Event(
            pet_id=pet_id,
            title=p.title, category=p.category, due_date=p.due_date,
            recurring=p.recurring, interval_days=p.interval_days,
            source_doc_id=p.source_doc_id, notes=p.notes, done=False,
        )
        db.add(e); rows.append(e)
    db.commit()
    for e in rows: db.refresh(e)
    # 사용자 이벤트도 함께 반환해서 클라이언트가 최신 전체 목록을 받게 함.
    user_rows = (
        db.query(Event)
        .filter(Event.pet_id == pet_id, Event.source_doc_id == USER_SOURCE)
        .all()
    )
    return [_to_out(e) for e in rows + user_rows]


@router.post("/{pet_id}", response_model=EventOut)
def create_event(pet_id: int, payload: EventCreate, db: Session = Depends(get_db)):
    pet = db.get(Pet, pet_id)
    if not pet:
        raise HTTPException(404, "pet not found")
    e = Event(
        pet_id=pet_id,
        title=payload.title,
        category=payload.category or "other",
        due_date=payload.due_date,
        recurring=payload.recurring,
        interval_days=payload.interval_days,
        source_doc_id=USER_SOURCE,
        notes=payload.notes,
        done=False,
    )
    db.add(e); db.commit(); db.refresh(e)
    return _to_out(e)


@router.get("/{pet_id}", response_model=List[EventOut])
def list_events(
    pet_id: int,
    start: Optional[date] = Query(None),
    end: Optional[date] = Query(None),
    include_done: bool = False,
    db: Session = Depends(get_db),
):
    q = db.query(Event).filter(Event.pet_id == pet_id)
    if start: q = q.filter(Event.due_date >= start)
    if end: q = q.filter(Event.due_date <= end)
    if not include_done: q = q.filter(Event.done.is_(False))
    return [_to_out(e) for e in q.order_by(Event.due_date).all()]


@router.get("/{pet_id}/upcoming", response_model=List[EventOut])
def upcoming(pet_id: int, days: int = 30, db: Session = Depends(get_db)):
    today = date.today()
    return list_events(
        pet_id=pet_id, start=today, end=today + timedelta(days=days),
        include_done=False, db=db,
    )


@router.patch("/event/{event_id}", response_model=EventOut)
def update_event(event_id: int, payload: EventUpdate, db: Session = Depends(get_db)):
    e = db.get(Event, event_id)
    if not e:
        raise HTTPException(404, "event not found")
    if payload.title is not None: e.title = payload.title
    if payload.category is not None: e.category = payload.category
    if payload.due_date is not None: e.due_date = payload.due_date
    if payload.recurring is not None: e.recurring = payload.recurring
    if payload.interval_days is not None: e.interval_days = payload.interval_days
    if payload.notes is not None: e.notes = payload.notes
    if payload.done is not None: e.done = payload.done
    db.commit(); db.refresh(e)
    return _to_out(e)


@router.delete("/event/{event_id}")
def delete_event(event_id: int, db: Session = Depends(get_db)):
    e = db.get(Event, event_id)
    if not e:
        raise HTTPException(404, "event not found")
    db.delete(e); db.commit()
    return {"ok": True}
