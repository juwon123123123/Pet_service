"""
Google Gemini 2.5 Flash Image (a.k.a. "nano-banana") 합성 호출.

입력: 펫 사진 + 상품 사진 + 프롬프트
출력: 합성된 이미지 바이트 (PNG/JPEG)

API key가 없으면 RuntimeError 발생. 호출부에서 catch해서 Generation.status='failed' 로 기록.
"""
from __future__ import annotations

import asyncio
import mimetypes
from functools import lru_cache
from pathlib import Path

from google import genai
from google.genai import types

from app.config import settings


@lru_cache(maxsize=1)
def _client() -> genai.Client:
    try:
        asyncio.get_event_loop()
    except RuntimeError:
        asyncio.set_event_loop(asyncio.new_event_loop())
    return genai.Client(api_key=settings.google_api_key)


def _mime(path: Path) -> str:
    m, _ = mimetypes.guess_type(str(path))
    return m or "image/jpeg"


_PROMPT_TEMPLATE = (
    "아래 첫 번째 이미지의 {species_ko} '{pet_name}'에게 두 번째 이미지의 상품"
    "({product_name}, 카테고리: {category})을 자연스럽게 착용/배치한 합성 사진을 만들어주세요."
    " 펫의 얼굴/털 특징은 그대로 유지하고, 조명과 그림자를 사실적으로 맞춰주세요."
    " 배경은 깔끔한 실내."
)


def generate_composite(
    pet_photo_path: Path,
    product_photo_path: Path,
    pet_name: str,
    species: str,
    product_name: str,
    category: str,
) -> bytes:
    if not settings.google_api_key:
        raise RuntimeError("GOOGLE_API_KEY 가 설정되어 있지 않음")

    species_ko = "강아지" if species == "dog" else "고양이"
    prompt = _PROMPT_TEMPLATE.format(
        species_ko=species_ko,
        pet_name=pet_name,
        product_name=product_name,
        category=category,
    )

    pet_bytes = pet_photo_path.read_bytes()
    product_bytes = product_photo_path.read_bytes()

    resp = _client().models.generate_content(
        model=settings.gemini_image_model,
        contents=[
            prompt,
            types.Part.from_bytes(data=pet_bytes, mime_type=_mime(pet_photo_path)),
            types.Part.from_bytes(data=product_bytes, mime_type=_mime(product_photo_path)),
        ],
    )

    # 응답 파트 중 inline_data(이미지)인 것을 첫 번째로 잡음.
    for cand in resp.candidates or []:
        for part in (cand.content.parts if cand.content else []):
            inline = getattr(part, "inline_data", None)
            if inline and inline.data:
                return inline.data
    raise RuntimeError("응답에서 이미지 파트를 찾지 못함")
