"""
파일 저장 추상화.

- 라우터/워커는 `storage.save(key, data, content_type)` / `storage.url(key)` 식으로 호출.
- 백엔드는 env var `STORAGE_BACKEND` 로 선택 (local | gcs).

키 형식은 두 백엔드 공통: `uploads/<category>/<filename>`
  - local: `./uploads/<category>/<filename>` 파일로 저장, `/uploads/...` 정적 URL 반환
  - gcs:   bucket 객체 `uploads/<category>/<filename>` 로 업로드, 공개 URL 반환

키에 `uploads/` 접두사를 유지하는 이유: 기존 SQLite/Postgres 데이터(path 컬럼)와 호환.
"""
from __future__ import annotations

import os
from abc import ABC, abstractmethod
from functools import lru_cache
from pathlib import Path

from app.config import settings


class Storage(ABC):
    @abstractmethod
    def save(self, key: str, data: bytes, content_type: str) -> None: ...
    @abstractmethod
    def delete(self, key: str) -> None: ...
    @abstractmethod
    def read_bytes(self, key: str) -> bytes: ...
    @abstractmethod
    def url(self, key: str) -> str: ...
    @abstractmethod
    def exists(self, key: str) -> bool: ...


class LocalStorage(Storage):
    """프로젝트 루트 기준으로 `key` 그대로 파일 저장."""

    def __init__(self, root: Path):
        self.root = root

    def _path(self, key: str) -> Path:
        return self.root / key

    def save(self, key: str, data: bytes, content_type: str) -> None:
        dest = self._path(key)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)

    def delete(self, key: str) -> None:
        try:
            self._path(key).unlink(missing_ok=True)
        except Exception:
            pass

    def read_bytes(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    def url(self, key: str) -> str:
        return f"/{key}"

    def exists(self, key: str) -> bool:
        return self._path(key).exists()


class GCSStorage(Storage):
    """Google Cloud Storage 버킷에 저장. 객체는 버킷 권한에 따라 공개 URL 접근."""

    def __init__(self, bucket_name: str):
        # 지연 import — local 모드에선 google-cloud-storage 미설치여도 동작하도록.
        from google.cloud import storage as gcs

        if not bucket_name:
            raise RuntimeError("GCS_BUCKET 환경변수가 비어있음")
        self._gcs = gcs
        self.client = gcs.Client()
        self.bucket = self.client.bucket(bucket_name)
        self.bucket_name = bucket_name

    def save(self, key: str, data: bytes, content_type: str) -> None:
        blob = self.bucket.blob(key)
        blob.upload_from_string(data, content_type=content_type)

    def delete(self, key: str) -> None:
        try:
            self.bucket.blob(key).delete()
        except Exception:
            pass

    def read_bytes(self, key: str) -> bytes:
        return self.bucket.blob(key).download_as_bytes()

    def url(self, key: str) -> str:
        return f"https://storage.googleapis.com/{self.bucket_name}/{key}"

    def exists(self, key: str) -> bool:
        return self.bucket.blob(key).exists()


@lru_cache(maxsize=1)
def get_storage() -> Storage:
    backend = (settings.storage_backend or "local").lower()
    if backend == "gcs":
        return GCSStorage(settings.gcs_bucket)
    # 기본: local. 프로젝트 루트(현재 cwd) 기준.
    return LocalStorage(Path(os.getcwd()))


# 편의 — `from app.storage import storage` 한 줄로.
class _StorageProxy:
    """라우터에서 `storage.save(...)` 호출 가능하게 하는 얇은 프록시."""
    def __getattr__(self, name):
        return getattr(get_storage(), name)


storage = _StorageProxy()
