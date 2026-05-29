"""
LLM 합성 (Gemini 2.5 Flash). 환각 방지를 위해:
  - 검색된 청크만 컨텍스트로 제공
  - 시스템 인스트럭션이 "컨텍스트 외 사실 금지" 명시
  - response_mime_type="application/json" 으로 JSON 강제
  - 응답 파싱 실패 시 컨텍스트만 묶는 fallback 가이드
"""
from __future__ import annotations

import asyncio
import json
from functools import lru_cache
from typing import Any

from google import genai
from google.genai import types

from app.config import settings
from app.rag.retriever import RetrievedChunk


@lru_cache(maxsize=1)
def _get_client() -> genai.Client:
    # Python 3.9 + uvloop 환경에서 워커 스레드에 이벤트 루프가 없으면
    # genai.Client 내부 asyncio.Lock() 초기화가 실패하므로 사전에 보장.
    try:
        asyncio.get_event_loop()
    except RuntimeError:
        asyncio.set_event_loop(asyncio.new_event_loop())
    return genai.Client(api_key=settings.google_api_key)


SYSTEM = """당신은 한국어 반려동물 케어 가이드를 작성하는 전문가입니다.
반드시 아래 컨텍스트에 명시된 내용만 사용하세요. 컨텍스트에 없는 날짜, 수치, 약품명, 횟수, 권고를 지어내지 마세요.
컨텍스트가 부족하면 그 항목은 "정보 없음"으로 표시하세요.
공식 가이드라인(WSAVA/AAHA/AAFP/CAPC 등)에서 인용한 내용은 본문에 "(WSAVA 2024, p.12)" 형식으로 출처를 함께 표기하세요.
출력은 반드시 다음 JSON 스키마를 따릅니다:

{
  "summary": "초보 반려인을 위한 2-4문장 요약",
  "sections": [
    {
      "topic": "예: 식이/예방접종/구충/위생/사회화",
      "advice": "마크다운 본문(단락 또는 불릿)",
      "citations": ["doc_id1", "doc_id2"]
    }
  ]
}

각 section의 citations에는 그 섹션을 작성할 때 실제로 참고한 컨텍스트 청크의 doc_id만 넣으세요.
JSON 외의 텍스트는 출력하지 마세요.
"""


def _build_context(chunks: list[RetrievedChunk]) -> str:
    parts = []
    for c in chunks:
        meta = c.meta
        attrs = [
            f"doc_id={c.doc_id}",
            f"category={meta.get('category','-')}",
            f"title={meta.get('title','-')}",
        ]
        if meta.get("source"):
            yr = f" {meta['year']}" if meta.get("year") else ""
            attrs.append(f"source={meta['source']}{yr}")
        if meta.get("page"):
            attrs.append(f"page={meta['page']}")
        header = "[" + " | ".join(attrs) + "]"
        parts.append(f"{header}\n{c.text}")
    return "\n\n---\n\n".join(parts)


def _build_user_prompt(pet: dict[str, Any], chunks: list[RetrievedChunk], topics) -> str:
    pet_block = (
        f"이름: {pet['name']}\n"
        f"종: {pet['species']}\n"
        f"품종: {pet.get('breed') or '미상'}\n"
        f"성별: {pet['sex']}\n"
        f"중성화 여부: {'예' if pet.get('neutered') else '아니오'}\n"
        f"생후 주수: {pet['age_weeks']}주 (약 {pet['age_months']}개월)\n"
        f"체중: {pet.get('weight_kg') or '미상'}kg\n"
    )
    topic_line = ("관심 주제: " + ", ".join(topics)) if topics else "관심 주제: 전반적인 케어"
    return (
        f"[펫 정보]\n{pet_block}\n[{topic_line}]\n\n"
        f"[참고 컨텍스트]\n{_build_context(chunks)}\n\n"
        "위 컨텍스트를 근거로 이 펫에게 적합한 가이드를 JSON으로 작성하세요."
    )


def generate_guide(pet: dict[str, Any], chunks: list[RetrievedChunk], topics=None) -> dict[str, Any]:
    if not settings.google_api_key:
        return _fallback_guide(chunks)

    client = _get_client()
    resp = client.models.generate_content(
        model=settings.gemini_model,
        contents=_build_user_prompt(pet, chunks, topics),
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM,
            response_mime_type="application/json",
            temperature=0.3,
            # Gemini 2.5 Flash 의 thinking 모드가 출력 토큰을 함께 소진하므로
            # JSON 본문이 잘리지 않도록 넉넉히 둠.
            max_output_tokens=8192,
        ),
    )
    text = (resp.text or "").strip()

    try:
        if text.startswith("```"):
            text = text.strip("`")
            text = text.split("\n", 1)[1] if text.startswith("json") else text
        data = json.loads(text)
        assert "summary" in data and "sections" in data
        return data
    except Exception:
        return _fallback_guide(chunks)


def _fallback_guide(chunks: list[RetrievedChunk]) -> dict[str, Any]:
    by_cat: dict[str, list[RetrievedChunk]] = {}
    for c in chunks:
        by_cat.setdefault(str(c.meta.get("category", "기타")), []).append(c)
    sections = []
    for cat, cs in by_cat.items():
        advice = "\n\n".join(f"- **{c.meta.get('title','')}**: {c.text}" for c in cs)
        sections.append(
            {"topic": cat, "advice": advice, "citations": [c.doc_id for c in cs]}
        )
    return {
        "summary": "지식베이스에서 회수된 항목을 카테고리별로 정리한 결과입니다 (LLM 합성 미사용).",
        "sections": sections,
    }
