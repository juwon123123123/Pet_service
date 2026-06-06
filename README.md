# PET TIMES 🐶🐱

> **초보 반려인을 위한 AI 케어 가이드 + 자동 캘린더 + 가상 옷 피팅 쇼핑몰** (Android 앱)
>
> RAG로 환각 없는 가이드를 만들고, 결정론적 알고리즘으로 케어 일정을 짜고,
> nano-banana(Gemini 2.5 Flash Image)로 우리 아이가 옷 입은 모습을 생성합니다.
> 전체 **GCP 클라우드 배포** (Cloud Run + Cloud SQL/pgvector + GCS).

---

## 핵심 기능

### 🐾 홈 (펫 정보)
- 사진 + 프로필 등록 / 수정 / 삭제 (수정 시 가이드·일정 자동 재생성)
- 종·품종·생년월일·체중 기반 자동 나이 계산
- **AI 케어 가이드**: 공식 가이드라인(WSAVA / AAHA / AAFP / CAPC) 기반 RAG
- 이번 주 일정 요약

### 📅 일정 (케어 캘린더)
- 월별 그리드 + 일별 상세
- **결정론적 자동 일정**: 종·생년월일·체중으로 접종/구충/중성화 일정을 수식 계산 (LLM 호출 0회)
- 직접 일정 등록/수정/삭제 (사용자 일정은 재생성해도 보존)

### 🛍 쇼핑 (AI 가상 피팅)
- 강아지 / 고양이 상품 카탈로그
- **AI 옷 추천**: 펫 프로필(종·체중)에 맞춰 스코어링으로 5개 상품 선정
- **nano-banana 합성**: 펫 사진 + 추천 상품 → "우리 아이가 그 옷을 입은 모습"을 백그라운드 생성, 폴링으로 그리드에 누적
- 실제 쇼핑몰 스타일 상세 페이지 (#태그 · 장바구니 · 구매)

---

## 기술 스택

### 모바일 (Flutter)
| 항목 | 기술 |
|---|---|
| 프레임워크 | Flutter 3.44 (Dart 3.12), Material 3 |
| HTTP / 업로드 | `http` + `http_parser` (멀티파트) |
| 상태 / 영속 | `ChangeNotifier` + `shared_preferences` |
| 이미지 | `image_picker` (카메라 / 갤러리) |
| 로케일 | `intl` + `flutter_localizations` (한국어) |

### 백엔드 (FastAPI)
| 항목 | 기술 |
|---|---|
| 웹 | FastAPI + Uvicorn (Python 3.11) |
| ORM | SQLAlchemy 2.0 / psycopg2 |
| 벡터 검색 | **pgvector** (코사인 거리) |
| 임베딩 | sentence-transformers `paraphrase-multilingual-MiniLM-L12-v2` (384-dim, 한국어) |
| LLM (텍스트) | Google **Gemini 2.5 Flash** (JSON 강제 출력) |
| LLM (이미지) | Google **Gemini 2.5 Flash Image** (nano-banana) |
| PDF 파싱 | pypdf |

### 인프라 (GCP, asia-northeast3)
| 컴포넌트 | 서비스 |
|---|---|
| 컨테이너 호스팅 | **Cloud Run** (min=1 / max=5, 2GiB, 2vCPU) |
| RDB + 벡터DB | **Cloud SQL** PostgreSQL 16 + pgvector |
| 파일 저장 | **Cloud Storage** (공개 읽기 버킷) |
| 시크릿 | **Secret Manager** (Gemini API 키) |
| 빌드 / 이미지 | Cloud Build + Artifact Registry |
| 인증 | IAM 서비스 계정 |

---

## 시스템 아키텍처

```
┌──────────────────────────────────────────────────────────────┐
│  📱 Flutter Android 앱  (홈 / 쇼핑 / 일정 3-tab)              │
│     기본 API URL = Cloud Run (dart-define으로 override 가능)  │
└───────────────────────────┬──────────────────────────────────┘
                            │ HTTPS REST
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  ☁️ Cloud Run  (FastAPI 컨테이너, 자동 스케일)               │
│   라우터: pets · calendar · guides · products · generations  │
│   AI:    RAG 검색+재순위 · Gemini 합성 · nano-banana         │
└──────┬────────────────────┬───────────────────┬──────────────┘
       │ Unix socket        │ GCS SDK           │ Secret Manager
       ▼                    ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Cloud SQL    │    │ GCS 버킷      │    │ Secret Mgr   │
│ PostgreSQL16 │    │ pet_photos/  │    │ gemini-key   │
│ + pgvector   │    │ products/    │    └──────┬───────┘
│              │    │ generated/   │           │
│ pets         │    │ (공개 읽기)   │    ┌──────▼───────┐
│ events       │    └──────────────┘    │ Gemini API   │
│ guides       │                        │ 2.5 Flash    │
│ products(50) │                        │ 2.5 Flash    │
│ generations  │                        │  Image       │
│ knowledge_   │◄── 벡터 검색(cosine)    │ (nano-banana)│
│  chunks(960) │                        └──────────────┘
└──────────────┘
       ▲  빌드/배포
┌──────┴───────────────────────────┐
│ Cloud Build → Artifact Registry  │
└──────────────────────────────────┘
```

---

## 두 가지 AI 서브시스템

### 1. RAG 가이드 생성 (텍스트)

```
펫 정보 → 임베딩(384-dim) → pgvector 코사인 검색(pool 20, WHERE species)
       → 휴리스틱 재순위(top 6) → Gemini 2.5 Flash(JSON) → 출처 부착
```

**휴리스틱 재순위 수식:**
```
score = (1 − cosine_distance)            # 의미 유사도
      + 0.35 if 종 일치
      + 0.55 if age_min_weeks ≤ 펫나이 ≤ age_max_weeks   ← 의료 핵심
      + 0.20 if 범위 밖이지만 12주 이내 근접
      + 0.10 if priority == "high"
```

**환각 방지 3중 장치:**
1. LLM 컨텍스트에 검색된 청크만 강제 주입
2. 시스템 프롬프트: "컨텍스트 외 사실 금지, 부족하면 '정보 없음'"
3. 응답 파싱 실패 시 컨텍스트 묶음 fallback 자동 전환
4. 캘린더 날짜는 LLM이 아닌 `birth_date + age_weeks × 7` 수식으로 계산

### 2. 옷 추천 + nano-banana 합성 (이미지)

**추천 스코어링 (LLM 미사용):**
```
score = 1.0
      + 0.5 if 종 일치 (dog/cat/both), 종 다르면 후보 제외
      + 0.5 if 펫 체중 ∈ [size_min_kg, size_max_kg]
      + uniform(0, 0.1)             # 결과 다양화용 jitter
```

**nano-banana 합성:**
```
펫 사진 + 상품 사진 + 프롬프트 → Gemini 2.5 Flash Image → 합성 이미지
```
5개 추천 상품을 FastAPI BackgroundTasks로 순차 실행 → Flutter가 4초 폴링으로 결과 누적.

---

## 데이터 모델 (Cloud SQL)

| 테이블 | 역할 | 핵심 컬럼 |
|---|---|---|
| `pets` | 반려동물 프로필 | species, breed, birth_date, neutered, weight_kg, **photo_path** |
| `events` | 캘린더 일정 | due_date, category, recurring, **source_doc_id** (user/시스템) |
| `guides` | AI 가이드 캐시 | summary, body_json (sections + citations) |
| `products` | 쇼핑몰 상품 50개 | species, category, price, image_path, tags, size_min/max_kg |
| `generations` | nano-banana 합성 job | pet_id, product_id, status, result_path |
| `knowledge_chunks` | **RAG 청크 960개** | text, **embedding VECTOR(384)**, doc_type, 스케줄 메타 |

**RAG 지식 2계층:**
| 종류 | doc_type | 개수 | 용도 |
|---|---|---|---|
| 큐레이션 .md | curated | 26 | 가이드 검색 **+ 캘린더 산출** |
| 공식 PDF (WSAVA/AAHA/AAFP/CAPC) | guideline | 934 | 가이드 검색·인용 보강 (캘린더 X) |

→ 캘린더는 스케줄 메타가 있는 curated 청크에서만 생성 → **날짜 환각 원천 차단**

---

## API 요약

| Method | Path | 설명 |
|---|---|---|
| POST | `/pets` | 펫 등록 |
| GET | `/pets`, `/pets/{id}` | 펫 조회 |
| PATCH | `/pets/{id}` | 프로필 수정 |
| DELETE | `/pets/{id}` | 펫 삭제 (cascade) |
| POST | `/pets/{id}/photo` | 사진 업로드 (multipart) |
| POST | `/guides` | RAG 기반 AI 가이드 생성 |
| GET | `/guides/{pet_id}/latest` | 최신 가이드 |
| POST | `/calendar/{pet_id}/rebuild` | 시스템 일정 재생성 (사용자 일정 보존) |
| GET | `/calendar/{pet_id}` , `/upcoming` | 월별 / 다가오는 일정 |
| POST | `/calendar/{pet_id}` | 일정 직접 추가 |
| PATCH/DELETE | `/calendar/event/{id}` | 일정 수정 / 완료 / 삭제 |
| GET | `/products?species=&category=` | 상품 목록 |
| GET | `/products/{id}` | 상품 상세 |
| POST | `/generations` | 추천 5개 + nano-banana 합성 시작 |
| GET | `/generations?pet_id=` | 합성 결과 폴링 |
| GET | `/generations/recommend/{pet_id}` | 추천만 조회 |

전체 스펙은 서버 실행 후 `/docs` (Swagger UI).

---

## 로컬 개발

### 백엔드 (로컬에서 직접 띄울 때)
```bash
# 의존성
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # GOOGLE_API_KEY 등 입력

# DB: Cloud SQL 사용 시 Auth Proxy 실행
./cloud-sql-proxy --port 5432 PROJECT:REGION:INSTANCE

# 지식 / 상품 시드
python -m scripts.seed_knowledge
python -m scripts.seed_products

# 서버
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Flutter
```bash
cd flutter_application
flutter pub get

# 배포된 Cloud Run에 붙어서 실행 (기본값)
flutter run -d android

# 로컬 백엔드에 붙으려면 dart-define으로 override
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

> 클론만 받아 `flutter run -d android` 하면 기본값(배포된 Cloud Run)에 자동 연결됩니다.

---

## 배포 (GCP)

```bash
# 1. 이미지 빌드 (임베딩 모델 prebake 포함)
gcloud builds submit \
  --tag asia-northeast3-docker.pkg.dev/PROJECT/pet-times/api

# 2. Cloud Run 배포 (최초 1회: env + secret + Cloud SQL 연결)
gcloud run deploy pet-times \
  --image=asia-northeast3-docker.pkg.dev/PROJECT/pet-times/api \
  --region=asia-northeast3 \
  --add-cloudsql-instances=PROJECT:REGION:INSTANCE \
  --update-secrets="GOOGLE_API_KEY=gemini-key:latest" \
  --env-vars-file=cloud-run-env.yaml \
  --service-account=SA@PROJECT.iam.gserviceaccount.com \
  --min-instances=1 --memory=2Gi --cpu=2 --allow-unauthenticated

# 이후 코드 수정 시: 빌드 → 이미지만 갱신
gcloud run deploy pet-times \
  --image=asia-northeast3-docker.pkg.dev/PROJECT/pet-times/api \
  --region=asia-northeast3
```

`cloud-run-env.yaml` 예시:
```yaml
STORAGE_BACKEND: gcs
GCS_BUCKET: <your-bucket>
DATABASE_URL: postgresql+psycopg2://USER:PASS@/pet_ai?host=/cloudsql/PROJECT:REGION:INSTANCE
```

---

## 디렉토리

```
app/
  main.py                  FastAPI entry + static mount (local 전용)
  config.py                .env 로딩
  storage.py               파일 저장 추상화 (local | gcs)
  models/schemas.py        Pydantic I/O 스키마
  db/
    database.py            SQLAlchemy 모델 (pgvector KnowledgeChunk 포함)
    vector_store.py        임베딩 + 청크 insert/검색 헬퍼
  rag/
    ingest.py              .md → pgvector (doc_type=curated)
    pdf_ingest.py          PDF → pgvector (doc_type=guideline)
    retriever.py           pgvector 검색 + 휴리스틱 재순위
    generator.py           Gemini 2.5 Flash (JSON, fallback)
  scheduler/converter.py   결정론적 캘린더 빌더
  shopping/
    recommender.py         종·체중 기반 상품 스코어링
    nano_banana.py         Gemini 2.5 Flash Image 합성 호출
  routers/{pets,guides,calendar,products,generations}.py
  data/knowledge/          *.md 시드
  data/sources/            공식 PDF + manifest.yaml

flutter_application/
  lib/
    main.dart              앱 진입 + 라우팅
    theme.dart             AppColors, 공통 위젯 테마
    api/{api_client,models}.dart
    state/pet_store.dart
    widgets/               공통 위젯 (AppCard, PrimaryButton, ScheduleCard ...)
    screens/
      onboarding · profile_setup · profile_edit · main_tab
      pet_info · calendar · event_editor · guide_detail
      shopping · product_list · product_detail · recommend_generate

scripts/
  seed_knowledge.py        .md + PDF 적재 (pgvector)
  seed_products.py         쇼핑몰 상품 50개 시드

Dockerfile / .dockerignore   Cloud Run 컨테이너 빌드
```

---

## 환경변수 (`.env`)

```ini
GOOGLE_API_KEY=...
GEMINI_MODEL=gemini-2.5-flash
GEMINI_IMAGE_MODEL=gemini-2.5-flash-image

# DB — 로컬 SQLite 또는 Cloud SQL Postgres
DATABASE_URL=postgresql+psycopg2://USER:PASS@127.0.0.1:5432/pet_ai

# 파일 저장 — local | gcs
STORAGE_BACKEND=gcs
GCS_BUCKET=<your-bucket>

EMBED_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
KNOWLEDGE_DIR=./app/data/knowledge
UPLOADS_DIR=./uploads
TOP_K=6
RECOMMEND_K=5
```

---

## 설계 노트 — "그냥 LLM API 호출"과의 차이

| 항목 | 단순 LLM 호출 | PET TIMES |
|---|---|---|
| 정보 출처 | 학습 데이터 (검증 불가) | 공식 가이드라인 청크 (출처 부착) |
| 캘린더 날짜 | LLM 생성 (환각 위험) | `birth_date + age_weeks×7` 수식 (재현 가능) |
| 종/연령 매칭 | 프롬프트 의존 | pgvector 필터 + 휴리스틱 재순위 (+0.55 age) |
| 상품 추천 | LLM이 고름 (느림/비용↑) | 종·체중 스코어링 (즉시, 무료) |
| 옷 합성 | 별도 모델 통합 필요 | nano-banana 멀티 이미지 입력 한 모델 |

> **검색·판단·스케줄링은 코드가 결정하고, LLM은 마지막 표현 레이어로만 사용**
> → 환각 차단 + 비용 최소화 + 결과 재현성 확보.

---

## 라이선스 & 데이터

- 코드: 학습 / 포트폴리오 용도.
- 지식 문서(`app/data/knowledge/*.md`)는 자체 작성.
- `app/data/sources/`의 PDF는 각 가이드라인 단체(WSAVA / AAHA / AAFP / CAPC) 저작권 — 학습/평가 외 재배포 금지.
- 상품 이미지는 데모용 가짜 데이터.
