# PET TIMES 🐶🐱

> **초보 반려인을 위한 AI 케어 가이드 + 자동 캘린더 + 가상 옷 피팅 쇼핑몰**
> RAG로 환각 없는 가이드를 만들고, 결정론적 알고리즘으로 일정을 짜고, nano-banana(Gemini 2.5 Flash Image)로 우리 아이가 옷 입은 모습을 생성합니다.

---

## 핵심 기능

### 🐾 펫 정보
- 사진 + 프로필 등록 / 수정 / 삭제
- 종·품종·생년월일·체중 기반 자동 나이 계산
- **AI 케어 가이드**: 공식 가이드라인(WSAVA / AAHA / AAFP / CAPC) 기반 RAG로 우리 아이 상태에 맞춘 케어 추천
- 이번 주 일정 요약

### 📅 케어 캘린더
- 월별 그리드 + 일별 상세
- **결정론적 자동 일정**: 종·생년월일·체중을 기반으로 접종/구충/중성화 등 일정을 수식으로 계산 (LLM 호출 0회)
- 직접 일정 등록/수정/삭제 가능 (사용자 일정은 재생성해도 보존됨)

### 🛍 쇼핑 (가상 피팅)
- 강아지 / 고양이 별 상품 카탈로그 (그리드)
- **AI 옷 추천**: 펫 프로필(연령/체중/계절)에 맞춰 태그 기반 스코어링으로 5개 상품 자동 선정
- **nano-banana 합성 이미지**: 펫 사진 + 추천 상품 → "우리 아이가 그 옷을 입은 모습"을 백그라운드로 생성, 결과를 그리드에 누적 표시
- 실제 쇼핑몰 스타일 상세 페이지 (가격·#태그·상품 정보·장바구니/구매)

---

## 기술 스택

| 레이어 | 사용 기술 |
|---|---|
| **모바일** | Flutter 3.44 (Material 3, 안드/iOS) |
| **백엔드** | FastAPI + Uvicorn (Python 3.9) |
| **RDB** | SQLite + SQLAlchemy |
| **벡터 DB** | ChromaDB (embedded, cosine) |
| **임베딩** | sentence-transformers `paraphrase-multilingual-MiniLM-L12-v2` (384-dim, 한국어 OK) |
| **LLM (텍스트)** | Google Gemini 2.5 Flash (JSON 강제 출력) |
| **LLM (이미지)** | Google Gemini 2.5 Flash Image (nano-banana) |
| **PDF 파싱** | pypdf |
| **이미지 처리** | Pillow, image_picker (Flutter) |

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter (펫 정보 / 쇼핑 / 캘린더 3-tab)                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │ REST (10.0.2.2:8000 on Android emu)
┌──────────────────────────▼──────────────────────────────────────┐
│  FastAPI                                                        │
│  ├─ pets, calendar          (CRUD + 결정론적 일정 빌드)          │
│  ├─ guides (RAG)            ──▶ ChromaDB ──▶ Gemini 2.5 Flash   │
│  ├─ products, generations   ──▶ recommender + nano-banana       │
│  └─ /uploads (static)       (사진 / 합성 결과 서빙)             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼───────────────────┐
        ▼                  ▼                   ▼
   SQLite             ChromaDB             Filesystem
  pets/events       knowledge chunks       uploads/
  guides/products    + PDF chunks          ├ pet_photos/
  generations                              ├ products/
                                           └ generated/
```

---

## 두 가지 AI 서브시스템

### 1. RAG 가이드 생성 (텍스트)

```
펫 정보 → query 구성 → ChromaDB 검색 (pool_k=20, where: species)
       → 휴리스틱 재순위 (top_k=6)
       → 컨텍스트 + 시스템 프롬프트 → Gemini 2.5 Flash (JSON)
       → 출처(doc_id, source, page) 부착 후 응답
```

**휴리스틱 재순위 수식**:
```
score = (1 - cosine_distance)            # 기본 유사도
      + 0.25 if species 정확 일치
      + 0.40 if age_min_weeks ≤ pet.age ≤ age_max_weeks
      + 0.15 if 범위 밖이지만 12주 이내
      + 0.10 if priority == "high"
      + 0.15 if breed 일치
```

**환각 방지**:
- LLM 컨텍스트에는 검색된 청크만 강제 주입
- 시스템 프롬프트: *"컨텍스트 외 사실 금지, 부족하면 '정보 없음'"*
- 캘린더 일정은 LLM이 만들지 않고 `birth_date + age_min_weeks * 7` 같은 수식으로 계산
- 응답 파싱 실패 시 컨텍스트 묶음 fallback 자동 전환

### 2. 옷 추천 + nano-banana 합성 (이미지)

**태그 기반 스코어링 (LLM 미사용)**:
```
score = 1.0
      + 0.6 if species 정확 일치  /  0.3 if "both"
      + 0.4 if 펫 체중이 size_min~max 범위 안  /  -0.3 if 명시되었는데 밖
      + 0.15 × |펫 태그 ∩ 상품 태그|
      + uniform(0, 0.1)             # 결과 다양화용 jitter
```

펫 태그는 자동 생성: 연령대(퍼피/성견/노령) + 종 + 체중대(소/중/대형) + 계절.

**nano-banana 합성**:
```python
client.models.generate_content(
    model="gemini-2.5-flash-image",
    contents=[
        prompt,  # "이 강아지에게 이 옷을 자연스럽게 입힌 합성을..."
        Part.from_bytes(pet_photo_bytes),
        Part.from_bytes(product_photo_bytes),
    ],
)
```
5개 추천 상품에 대해 FastAPI BackgroundTasks가 순차 실행 → Flutter 클라이언트가 4초 폴링으로 결과 누적 표시.

---

## 빠른 시작

### 1. 백엔드

```bash
# 의존성
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 환경변수
cp .env.example .env
# .env 의 GOOGLE_API_KEY 입력

# RAG 지식 적재 (.md 시드 + 옵션 PDF)
python -m scripts.seed_knowledge

# 가짜 쇼핑몰 상품 적재 (사진은 uploads/products/ 에 둘 것)
python -m scripts.seed_products

# 서버 실행 (0.0.0.0 — 안드 에뮬에서 10.0.2.2로 접근)
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 2. Flutter (Android Studio 에뮬레이터)

```bash
cd flutter_application
flutter pub get
flutter run
```

- 안드 에뮬레이터는 `http://10.0.2.2:8000` 자동 사용
- iOS / macOS / Web 은 `http://127.0.0.1:8000` 자동
- 실기기: `flutter run --dart-define=API_BASE_URL=http://<PC-IP>:8000`

---

## API 요약

| Method | Path | 설명 |
|---|---|---|
| POST | `/pets` | 펫 등록 |
| GET | `/pets`, `/pets/{id}` | 펫 조회 |
| PATCH | `/pets/{id}` | 프로필 수정 |
| DELETE | `/pets/{id}` | 펫 삭제 (관련 데이터 cascade) |
| POST | `/pets/{id}/photo` | 사진 업로드 (multipart) |
| POST | `/guides` | RAG 기반 AI 가이드 생성 |
| GET | `/guides/{pet_id}/latest` | 최신 가이드 조회 |
| POST | `/calendar/{pet_id}/rebuild` | 시스템 일정 재생성 (사용자 일정 보존) |
| GET | `/calendar/{pet_id}` | 월별 조회 |
| GET | `/calendar/{pet_id}/upcoming?days=` | 다가오는 일정 |
| POST | `/calendar/{pet_id}` | 일정 직접 추가 |
| PATCH | `/calendar/event/{id}` | 일정 수정 / 완료 토글 |
| DELETE | `/calendar/event/{id}` | 일정 삭제 |
| GET | `/products?species=&category=` | 상품 목록 |
| GET | `/products/{id}` | 상품 상세 |
| POST | `/products/upload_image` | 상품 사진 업로드 |
| POST | `/products` | 상품 등록 |
| POST | `/generations` | 추천 5개 + nano-banana 합성 job 시작 |
| GET | `/generations?pet_id=` | 합성 결과 폴링 |
| GET | `/generations/recommend/{pet_id}` | 추천만 조회 (이미지 X) |
| DELETE | `/generations/{id}` | 합성 결과 삭제 |

전체 스펙은 서버 실행 후 [http://localhost:8000/docs](http://localhost:8000/docs).

---

## 디렉토리

```
app/
  main.py                  FastAPI entry + static mount
  config.py                .env 로딩
  models/schemas.py        Pydantic I/O 스키마
  db/database.py           SQLite (pets / events / guides / products / generations)
  db/vector_store.py       ChromaDB + 임베딩 함수
  rag/
    ingest.py              .md → ChromaDB (doc_type=curated)
    pdf_ingest.py          PDF → ChromaDB (doc_type=guideline)
    retriever.py           검색 + 메타 필터 + 휴리스틱 재순위
    generator.py           Gemini 2.5 Flash (JSON, fallback)
  scheduler/converter.py   결정론적 캘린더 빌더
  shopping/
    recommender.py         태그 기반 상품 스코어링
    nano_banana.py         Gemini 2.5 Flash Image 합성 호출
  routers/{pets,guides,calendar,products,generations}.py
  data/knowledge/          *.md 시드 (캘린더 단일 출처)
  data/sources/            공식 PDF + manifest.yaml

flutter_application/
  lib/
    main.dart              앱 진입 + 라우팅
    theme.dart             AppColors, softShadow, categoryLabel
    api/
      api_client.dart      HTTP 클라이언트 (BaseUrl 자동 분기)
      models.dart          Pet / Event / Guide / Product / Generation
    state/pet_store.dart   SharedPreferences + ChangeNotifier
    widgets/               AppCard, PrimaryButton, ScheduleCard, ...
    screens/
      onboarding.dart      시작 화면
      profile_setup.dart   펫 등록 (사진 picker 포함)
      profile_edit.dart    펫 수정 → 저장 시 가이드+캘린더 자동 재생성
      main_tab.dart        하단 3-탭 (펫 정보 / 쇼핑 / 캘린더)
      pet_info.dart        펫 카드 + 이번주 일정 + AI 가이드 + 메뉴
      calendar.dart        월별 그리드 + CRUD + 재생성 FAB
      event_editor.dart    일정 생성/수정 모달
      shopping.dart        3 서브탭 (고양이 / 추천 생성 / 강아지)
      product_list.dart    상품 그리드
      product_detail.dart  쇼핑몰 스타일 풀페이지
      recommend_generate.dart  추천+합성, 4초 폴링
      guide_detail.dart    가이드 상세

scripts/
  seed_knowledge.py        .md + PDF 일괄 적재
  seed_products.py         가짜 쇼핑몰 50개 상품 시드

uploads/
  pet_photos/              펫 사진 (업로드 결과)
  products/                상품 사진 (사용자 사전 배치)
  generated/               nano-banana 합성 결과
```

---

## 지식 문서 포맷

`app/data/knowledge/*.md` — YAML 프론트매터 + 본문.

```markdown
---
id: dog_vaccine_dhppl_1            # 고유 ID (캘린더의 source_doc_id로 사용)
species: dog                        # dog | cat | both
category: vaccination               # feeding / vaccination / parasite / surgery / hygiene / checkup / training
title: 종합백신(DHPPL) 1차
age_min_weeks: 6                    # (있으면) 1회성 이벤트 산출에 사용
age_max_weeks: 8
recurring: false                    # 또는 true + interval_days + start_age_weeks
priority: high
---
본문: 검색 컨텍스트 + 이벤트 notes로 사용됨.
```

### 두 종류의 지식, 한 컬렉션

| | 형식 | doc_type | 용도 |
|---|---|---|---|
| 큐레이션 시드 | `.md` (프론트매터) | `curated` | **가이드 검색 + 캘린더 산출** |
| 공식 가이드라인 | PDF (페이지 청크 ~900자) | `guideline` | **가이드 검색·인용 보강 (캘린더 X)** |

캘린더는 `age_min_weeks/max_weeks` 또는 `recurring + interval_days + start_age_weeks` 메타가 있는 청크에서만 만들어집니다. PDF 청크에는 이 필드가 없으므로 캘린더에 자동 반영되지 않아 **날짜 환각이 원천 차단**됩니다.

---

## 상품 데이터 추가하기

```bash
# 1) 사진을 ./uploads/products/ 에 두기
cp ~/Downloads/dog_padding.jpg uploads/products/dog_padding.jpg

# 2-a) 시드 스크립트 (scripts/seed_products.py)의 PRODUCTS 리스트 수정 후 실행
python -m scripts.seed_products

# 2-b) 또는 API로 직접 등록
curl -X POST http://127.0.0.1:8000/products/upload_image -F 'file=@photo.jpg'
# → {"image_path":"uploads/products/product_xxx.jpg", ...}

curl -X POST http://127.0.0.1:8000/products \
  -H 'Content-Type: application/json' \
  -d '{
    "name":"포근 패딩","species":"dog","category":"옷","price":29900,
    "image_path":"uploads/products/product_xxx.jpg",
    "tags":["겨울","방한"], "size_min_kg":2, "size_max_kg":8
  }'
```

---

## 환경변수 (`.env`)

```ini
GOOGLE_API_KEY=YOUR_GEMINI_KEY
GEMINI_MODEL=gemini-2.5-flash
GEMINI_IMAGE_MODEL=gemini-2.5-flash-image
DATABASE_URL=sqlite:///./pet_ai.db
CHROMA_DIR=./chroma_store
EMBED_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
KNOWLEDGE_DIR=./app/data/knowledge
UPLOADS_DIR=./uploads
TOP_K=6
RECOMMEND_K=5
```

---

## 설계 노트 / 차별점

**"그냥 ChatGPT API 한 번 호출" 과 무엇이 다른가?**

| 항목 | 단순 LLM 호출 | 본 프로젝트 |
|---|---|---|
| 정보 출처 | 학습 데이터 (검증 불가) | 공식 가이드라인 청크 (출처 부착) |
| 캘린더 날짜 | LLM이 생성 (할루시네이션 위험) | `birth_date + age_min_weeks*7` 수식 (재현 가능) |
| 종/연령 매칭 | 프롬프트 의존 | ChromaDB `where` 필터 + 휴리스틱 재순위 (+0.4 age hit) |
| 상품 추천 | LLM이 골라줌 (느림/비용↑) | 태그 스코어링 (즉시, 무료) |
| 옷 합성 | 별도 모델 통합 필요 | nano-banana 한 모델로 멀티 이미지 입력 처리 |

**결과**: 검색·판단·스케줄링은 우리 코드가 결정하고, LLM은 마지막 표현 레이어로만 쓰임 → 환각 차단 + 비용 최소화 + 결과 재현성 확보.

---

## 라이선스 & 데이터

- 코드: 학습/포트폴리오 용도. 상업적 사용 전 문의.
- 지식 문서: `app/data/knowledge/*.md` 는 자체 작성.
- `app/data/sources/` 의 PDF는 각 가이드라인 단체(WSAVA / AAHA / AAFP / CAPC)의 저작권. 학습/평가 외 재배포 금지.
- `uploads/products/` 의 상품 이미지는 데모/시드용 가짜 데이터.

---

## TODO / 확장 아이디어

- 푸시 알림 (`/calendar/{pet}/upcoming?days=1` 폴링 워커)
- 실제 결제 연동 (현재는 SnackBar 가짜 결제)
- cross-encoder 재순위 (현재는 휴리스틱)
- 다견·다묘 가구 지원 (현재 SharedPreferences에 단일 pet_id)
- 사용자 직접 추가 옷 → 합성 (커스텀 옷)
