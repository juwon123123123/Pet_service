# PET TIMES backend — FastAPI + RAG (pgvector) + nano-banana
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/app/.cache/huggingface \
    TRANSFORMERS_OFFLINE=0

WORKDIR /app

# torch (sentence-transformers 의존) 는 libgomp1 필요
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 의존성 먼저 설치 (Docker 레이어 캐시 활용)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 임베딩 모델을 이미지에 미리 다운로드 → cold start 시 모델 fetch 시간 절감 (~5초 → ~1초)
RUN python -c "from sentence_transformers import SentenceTransformer; \
    SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')"

# 앱 코드
COPY app/ ./app/
COPY scripts/ ./scripts/

# Cloud Run 은 $PORT (기본 8080) 로 바인딩 요구
ENV PORT=8080
EXPOSE 8080

CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
