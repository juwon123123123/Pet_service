# Pet AI — 서비스 흐름 & 아키텍처 (기말 프로젝트용)

## 1. 한 줄 요약
초보 반려인이 자기 펫의 정보를 입력하면, **공식 가이드라인(WSAVA/AAHA/AAFP/CAPC)** 과 **큐레이션 시드 지식**을 RAG로 검색해 개인화된 케어 가이드를 만들고, 동일 지식의 구조화된 메타데이터로 환각 없는 캘린더를 자동 생성하는 백엔드.

## 2. 전체 데이터 흐름

```
┌─────────────────────────────────────────────────────────────────────────┐
│ [1] 사용자 입력 레이어                                                  │
│  - POST /pets : 이름, 종(dog/cat), 품종, 생년월일, 성별, 중성화, 체중   │
│  → SQLite의 pets 테이블에 저장. age_weeks/age_months 자동 계산          │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ [2] 지식베이스 (RAG)                                                    │
│  ┌───────────────────────────┐    ┌──────────────────────────────────┐ │
│  │ 큐레이션 시드 (.md)        │    │ 공식 가이드라인 PDF              │ │
│  │  - YAML 프론트매터         │    │  - WSAVA 2024 백신              │ │
│  │  - age_min/max_weeks       │    │  - AAHA 2022 개 백신/Life Stage │ │
│  │  - recurring/interval_days │    │  - AAHA/AAFP 2020·2021 고양이   │ │
│  │  - doc_type = "curated"    │    │  - WSAVA GNC 영양               │ │
│  │                            │    │  - CAPC 구충                    │ │
│  │                            │    │  - doc_type = "guideline"        │ │
│  └─────────────┬──────────────┘    └────────────┬─────────────────────┘ │
│                ▼                                ▼                       │
│       sentence-transformers (paraphrase-multilingual-MiniLM-L12-v2)     │
│                              ▼                                          │
│                      ChromaDB (cosine)                                  │
│        하나의 컬렉션 "pet_knowledge" — 메타로 doc_type 구분             │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ [3] 가이드 생성 엔진  (POST /guides)                                    │
│  1) 펫의 species/age_weeks/breed로 쿼리 구성                            │
│  2) ChromaDB 검색: where={"species":{"$in":[species,"both"]}}, k=20    │
│  3) 휴리스틱 재순위:                                                    │
│     +0.25 종 일치  +0.4 연령범위 적중  +0.15 인접  +0.15 품종 일치    │
│     +0.1  priority=high                                                 │
│  4) 상위 top_k(=6) 청크를 컨텍스트로 묶음. 각 청크 헤더에                │
│     doc_id / source / year / page 노출                                  │
│  5) Gemini 2.5 Flash에 system 프롬프트로 "컨텍스트 외 사실 금지"       │
│     JSON 스키마 강제: {summary, sections:[{topic,advice,citations[]}]}  │
│  6) 실패 시 LLM 없이 컨텍스트만 묶은 fallback 가이드 반환               │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ [4] 스케줄 변환기  (POST /calendar/{pet_id}/rebuild)                    │
│  - 메타에 age_min/max_weeks 가 있는 청크 → 1회성 이벤트                 │
│       due_date = birth_date + midpoint((min+max)/2 weeks)               │
│  - 메타에 recurring=true 가 있는 청크 → 반복 이벤트                     │
│       anchor = birth_date + start_age_weeks                             │
│       이미 지난 anchor는 today 이후로 점프, interval_days로 horizon까지 │
│  ⚠ PDF 청크는 schedule 메타가 없으므로 자동 제외 → 캘린더 환각 0        │
│  - 미완료 이벤트는 삭제 후 재생성, 완료 이벤트는 이력 보존              │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ [5] 캘린더 & 알림                                                       │
│  - GET  /calendar/{pet_id}           : 기간/완료여부 필터               │
│  - GET  /calendar/{pet_id}/upcoming  : 다가오는 N일 (앱·푸시 폴링용)    │
│  - PATCH /calendar/event/{id}        : 완료 처리, 날짜 변경             │
│  - DELETE /calendar/event/{id}                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 3. 환각 방지 3중 가드

| 단계 | 가드 | 효과 |
|---|---|---|
| 검색 | 종 + 연령 메타 필터 → 무관 문서 차단 | 부정확한 컨텍스트 유입 차단 |
| 생성 | system 프롬프트 + JSON 강제 + citations 필수 | LLM이 컨텍스트 외 사실 못 만듦 |
| 일정 | LLM이 날짜 만들지 않음. 모든 due_date = 구조화 메타에서 계산 | 일정 오류·환각 원천 차단 |

## 4. API 한눈에

| Method | Path | 설명 |
|---|---|---|
| POST | `/pets` | 펫 등록 |
| GET | `/pets` `/pets/{id}` | 조회 |
| DELETE | `/pets/{id}` | 삭제 (이벤트/가이드 cascade) |
| POST | `/guides` `{pet_id, topics?}` | 가이드 생성·저장 |
| GET | `/guides/{pet_id}/latest` | 최근 가이드 조회 |
| POST | `/calendar/{pet_id}/rebuild` | 메타 기반 이벤트 재생성 |
| GET | `/calendar/{pet_id}` | 이벤트 목록 (필터) |
| GET | `/calendar/{pet_id}/upcoming?days=N` | 알림용 |
| PATCH | `/calendar/event/{id}` | 완료/날짜 변경 |
| DELETE | `/calendar/event/{id}` | 삭제 |

## 5. 사용자 여정 (예: 생후 7주 말티즈 등록)

1. **회원 = 펫 등록** → `POST /pets`
2. **가이드 요청** → `POST /guides {pet_id:1}`
   - 검색 결과 예: `dog_vaccine_dhppl_1`(연령 적중), `dog_feeding_puppy`, `dog_socialization`, WSAVA 2024 p.12 청크(공식 인용)
   - 반환: summary + 식이/접종/사회화 섹션 + citations(WSAVA, AAHA 포함)
3. **캘린더 빌드** → `POST /calendar/1/rebuild`
   - 산출 이벤트 예시:
     - 2026-06-15 DHPPL 2차 (생후 9-11주 중간점)
     - 2026-07-06 DHPPL 3차
     - 2026-08-03 광견병 1차
     - 매월 26일 심장사상충 예방약 (반복)
     - 매월 12일 내·외부 구충 (반복)
4. **앱에서 푸시** → `GET /calendar/1/upcoming?days=7` 폴링 → 알림 발송
5. **체크** → `PATCH /calendar/event/3 {done:true}`

## 6. 기술 선택 근거 (발표 슬라이드용)

- **FastAPI** : Pydantic v2와 자동 OpenAPI로 시연·문서화 효율 최대
- **SQLite** : 외부 의존성 없는 임베디드 DB → 평가자 환경에서 바로 동작
- **ChromaDB(임베디드)** : 별도 서버 없이 파일 기반 영구 저장
- **sentence-transformers 다국어** : 한국어 질의·문서 모두 처리 + 오프라인
- **Gemini 2.5 Flash** : 빠르고 저렴하며 `response_mime_type=application/json`로 JSON 강제 지원
- **휴리스틱 재순위** : cross-encoder 추가 없이도 메타로 강력한 신호 확보
- **메타 기반 결정론적 캘린더** : "RAG 환각" 문제를 구조적으로 회피

## 7. 평가 시나리오 제안

1. **재현성**: `pip install` → `seed_knowledge` → `uvicorn` 3-step 데모.
2. **환각 테스트**: 시드에 없는 종(e.g. species=rabbit)으로 요청 → 404/정보없음 응답.
3. **출처 검증**: 응답의 citations.source 가 컨텍스트로 들어간 청크에만 나타나는지 비교.
4. **캘린더 일관성**: 동일 펫에 대해 두 번 rebuild → 같은 일정 (결정론) 확인.
5. **다국어 검색**: "심장사상충", "heartworm" 둘 다 같은 문서가 회수되는지 확인.

## 8. 향후 확장

- 알림 워커: cron + FCM/APNS로 `/upcoming?days=1` 폴링.
- 품종별 가중: 시드 `.md` 에 `breed:` 필드 추가 → 자동 재순위 반영됨.
- 강한 재순위: `retriever.py` 의 휴리스틱을 multilingual cross-encoder로 교체.
- 이미지 입력: 펫 사진 → 품종 추정 → species/breed 자동 채움.
- iCal export: `/calendar/{pet}/ical` 추가하면 구글 캘린더 연동.
