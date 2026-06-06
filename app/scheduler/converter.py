from __future__ import annotations
"""
가이드/지식문서 -> 캘린더 이벤트.

LLM은 절대 날짜를 만들지 않습니다. 모든 due_date는
  birth_date + 메타데이터(age_min_weeks/max_weeks/start_age_weeks)
에서 결정론적으로 산출됩니다.
"""

from dataclasses import dataclass
from datetime import date, timedelta

from app.rag.retriever import all_relevant_for_schedule


@dataclass
class PlannedEvent:
    title: str
    category: str
    due_date: date
    recurring: bool
    interval_days: int | None
    source_doc_id: str
    notes: str | None


def _midpoint_due(birth: date, amin_w: int, amax_w: int, today: date) -> date:
    mid_days = ((amin_w + amax_w) * 7) // 2
    return birth + timedelta(days=mid_days)


def build_schedule(
    pet_birth: date,
    species: str,
    age_weeks: int,
    today: date,
    horizon_days: int = 365,
) -> list[PlannedEvent]:
    chunks = all_relevant_for_schedule(species, age_weeks)
    events: list[PlannedEvent] = []
    horizon_end = today + timedelta(days=horizon_days)

    for c in chunks:
        m = c.meta
        title = str(m.get("title", "케어 항목"))
        category = str(m.get("category", "기타"))

        amin = m.get("age_min_weeks")
        amax = m.get("age_max_weeks")
        if amin is not None and amax is not None:
            due = _midpoint_due(pet_birth, int(amin), int(amax), today)
            # 과거에 이미 지난 1회성 일정도 보존하되, 지나치게 오래된 건 제외
            if due >= today - timedelta(days=30) and due <= horizon_end:
                events.append(
                    PlannedEvent(
                        title=title,
                        category=category,
                        due_date=due,
                        recurring=False,
                        interval_days=None,
                        source_doc_id=c.doc_id,
                        notes=_short_notes(c.text),
                    )
                )

        if m.get("recurring"):
            interval = int(m.get("interval_days", 30))
            start_age_w = int(m.get("start_age_weeks", 0))
            end_age_w = m.get("end_age_weeks")
            anchor = pet_birth + timedelta(weeks=start_age_w)
            if anchor < today:
                # today 이후로 이동
                missed = (today - anchor).days // interval + 1
                anchor = anchor + timedelta(days=missed * interval)
            cursor = anchor
            while cursor <= horizon_end:
                if end_age_w is not None:
                    if cursor > pet_birth + timedelta(weeks=int(end_age_w)):
                        break
                events.append(
                    PlannedEvent(
                        title=title,
                        category=category,
                        due_date=cursor,
                        recurring=True,
                        interval_days=interval,
                        source_doc_id=c.doc_id,
                        notes=_short_notes(c.text),
                    )
                )
                cursor += timedelta(days=interval)

    events.sort(key=lambda e: e.due_date)
    return events


def _short_notes(text: str, limit: int = 240) -> str:
    t = text.strip().replace("\n", " ")
    return t if len(t) <= limit else t[:limit] + "…"


def compute_age(birth: date, today: date) -> tuple[int, float]:
    days = (today - birth).days
    weeks = max(days // 7, 0)
    months = round(days / 30.4375, 1)
    return weeks, months
