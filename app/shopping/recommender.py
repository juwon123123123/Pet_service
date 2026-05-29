"""
태그 기반 상품 추천 (LLM 미사용, 결정론적 + 약간의 무작위).

스코어 공식:
    base       = 1.0
    species   += 0.6  if product.species == pet.species
                 0.3  if product.species == "both"
    size       += 0.4 if pet.weight_kg ∈ [size_min_kg, size_max_kg]
                 -0.3  if 명시되었는데 범위 밖
    tag_overlap+= 0.15 * (펫 태그 ∩ 상품 태그)의 개수
    jitter     += uniform(0, 0.1)   # 같은 호출이라도 결과 일부 변동
"""
from __future__ import annotations

import random
from dataclasses import dataclass
from datetime import date
from typing import Optional

from app.db.database import Pet, Product
from app.scheduler.converter import compute_age


@dataclass
class Scored:
    product: Product
    score: float


def _pet_tags(pet: Pet) -> set[str]:
    """펫의 자체 태그 집합. 상품 태그와 단순 교집합으로 매칭."""
    weeks, _ = compute_age(pet.birth_date, date.today())
    tags: set[str] = set()
    # 연령대
    if weeks < 16:
        tags |= {"퍼피", "키튼", "어린", "성장기"}
    elif weeks < 52:
        tags |= {"청년", "어린"}
    elif weeks < 52 * 7:
        tags |= {"성견" if pet.species == "dog" else "성묘", "성체"}
    else:
        tags |= {"노령", "시니어"}
    # 종
    tags.add(pet.species)
    if pet.species == "dog":
        tags.add("강아지")
    elif pet.species == "cat":
        tags.add("고양이")
    # 체중대(소형/중형/대형) — 강아지 기준
    if pet.species == "dog" and pet.weight_kg is not None:
        if pet.weight_kg < 7:
            tags |= {"소형", "소형견"}
        elif pet.weight_kg < 20:
            tags |= {"중형", "중형견"}
        else:
            tags |= {"대형", "대형견"}
    # 계절 (현재 월 기준)
    m = date.today().month
    if m in (12, 1, 2):
        tags.add("겨울")
    elif m in (3, 4, 5):
        tags.add("봄")
    elif m in (6, 7, 8):
        tags.add("여름")
    else:
        tags.add("가을")
    return tags


def _product_tags(p: Product) -> set[str]:
    if not p.tags:
        return set()
    return {t.strip() for t in p.tags.split(",") if t.strip()}


def score(pet: Pet, product: Product, rng: random.Random) -> float:
    s = 1.0
    # 종
    if product.species == pet.species:
        s += 0.6
    elif product.species == "both":
        s += 0.3
    else:
        # 종 자체가 다르면 0점 처리 (recommend()에서 0 이하 제외)
        return 0.0

    # 사이즈 매칭
    if product.size_min_kg is not None or product.size_max_kg is not None:
        if pet.weight_kg is None:
            # 체중 모르면 가산/감산 없음
            pass
        else:
            lo = product.size_min_kg if product.size_min_kg is not None else 0
            hi = product.size_max_kg if product.size_max_kg is not None else 1e9
            if lo <= pet.weight_kg <= hi:
                s += 0.4
            else:
                s -= 0.3

    # 태그 교집합
    overlap = _pet_tags(pet) & _product_tags(product)
    s += 0.15 * len(overlap)

    # 결과 다양화를 위한 작은 jitter
    s += rng.uniform(0, 0.1)
    return s


def recommend(
    pet: Pet,
    products: list[Product],
    k: int = 5,
    seed: Optional[int] = None,
) -> list[Scored]:
    rng = random.Random(seed)
    scored = [Scored(p, score(pet, p, rng)) for p in products if p.is_active]
    scored = [s for s in scored if s.score > 0]
    scored.sort(key=lambda x: x.score, reverse=True)
    return scored[:k]
