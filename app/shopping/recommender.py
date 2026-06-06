"""
상품 추천 (LLM 미사용, 결정론적 + 약간의 무작위).

스코어 공식:
    base     = 1.0
    species += 0.5  if 종 일치 (dog/cat/both) , 종 다르면 제외
    size    += 0.5  if 펫 체중 ∈ [size_min_kg, size_max_kg]
    jitter  += uniform(0, 0.1)   # 같은 호출이라도 결과 일부 변동
"""
from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Optional

from app.db.database import Pet, Product


@dataclass
class Scored:
    product: Product
    score: float


def score(pet: Pet, product: Product, rng: random.Random) -> float:
    s = 1.0

    # 종 — 일치(전용 또는 공용)면 +0.5, 다르면 후보에서 제외.
    if product.species in (pet.species, "both"):
        s += 0.5
    else:
        return 0.0

    # 체중 — 상품에 사이즈 범위가 있고 펫 체중이 그 안이면 +0.5.
    if (
        pet.weight_kg is not None
        and (product.size_min_kg is not None or product.size_max_kg is not None)
    ):
        lo = product.size_min_kg if product.size_min_kg is not None else 0
        hi = product.size_max_kg if product.size_max_kg is not None else 1e9
        if lo <= pet.weight_kg <= hi:
            s += 0.5

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
