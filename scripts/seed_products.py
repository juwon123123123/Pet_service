#!/usr/bin/env python3
"""
가짜 쇼핑몰 상품 시드 (cloth1.jpg ~ cloth50.jpg, 모두 의류).

배치:
  cloth1  ~ cloth25 → 강아지 옷 25개
  cloth26 ~ cloth50 → 고양이 옷 25개

각 상품 마다:
  - 한국어 이름 (스타일 + 컬러/모티프)
  - price (12,900 ~ 79,000 원, 1000원 단위)
  - tags (계절 + 스타일 + 핏 + 시즌 이벤트 등 4~6개)
  - size_min_kg / size_max_kg (강아지는 소/중/대형 mix, 고양이는 None)

다시 채우고 싶으면 sqlite3 명령으로 products 비우고 재실행:
  sqlite3 pet_ai.db "DELETE FROM products;"
  .venv/bin/python -m scripts.seed_products
"""
import mimetypes
from pathlib import Path

from app.db.database import Product, SessionLocal, init_db
from app.storage import storage

UPLOAD_DIR = Path("uploads/products")


# (name, price, tags, size_min, size_max)  — size_min/max는 강아지만 의미 있음.
# size 그룹: 소형(2-7), 중형(7-15), 대형(15-30), 프리(None/None)
DOGS = [
    # cloth1
    ("애완 회색 후드티",           29900, ["겨울", "방한", "패딩", "산책"], 2, 7),
    ("애완 검정 후드티",         15900, ["봄", "가을", "데일리", "후드"], 2, 7),
    ("애완 빨강 후드티",         24900, ["봄", "여아", "원피스"], 3, 8),
    ("회색 면티",       35000, ["겨울", "방한", "플리스"], 5, 12),
    ("노란 면티",     27900, ["봄", "가을", "방풍", "산책"], 3, 10),  # 5
    ("헬로키티 흰 티",          12900, ["여름", "통풍", "쿨링"], 2, 8),
    ("헬로키티 검정 티",        18900, ["여름", "장마", "방수", "우비"], 3, 12),
    ("블루 후드티",        21900, ["겨울", "데일리", "니트"], 2, 7),
    ("블랙 후드티",         16900, ["겨울", "크리스마스", "코스튬", "이벤트"], 3, 9),
    ("화이트 후드티",      14900, ["가을", "할로윈", "코스튬", "이벤트"], 3, 9),  # 10
    ("네이비 후드티",        22900, ["봄", "가을", "데일리", "데님"], 3, 10),
    ("올리브 후드티",      19900, ["봄", "여름", "데일리", "폴로"], 3, 8),
    ("레드 스프라이트 면티",          26900, ["겨울", "방한", "조끼"], 5, 14),
    ("블루 스프라이트 면티",          39900, ["겨울", "방한", "후드", "산책"], 8, 18),
    ("기본 스프라이트 면티",            17900, ["봄", "여름", "데일리"], 2, 6),       # 15
    ("크리스마스 산타 후드티",        45900, ["가을", "겨울", "트렌치", "외출"], 4, 12),
    ("심플 레드 기본 티 ",          18900, ["가을", "겨울", "니트"], 2, 8),
    ("심플 블루 기본 티",          11900, ["봄", "여름", "데일리"], 2, 7),
    ("심플 블랙 기본 티",        16900, ["봄", "여아", "원피스", "이벤트"], 2, 6),
    ("애완 옐로우 우비",          15900, ["봄", "여름", "데일리"], 3, 9),       # 20
    ("애완 퍼플 우비",          32900, ["설날", "한복", "이벤트"], 3, 9),
    ("애완 올리브 우비",      33900, ["겨울", "산책", "야간", "반사"], 5, 14),
    ("스프라이트 포차코 옐로우 티",        58000, ["겨울", "방한", "패딩", "대형"], 15, 30),
    ("스프라이트 포차코 핑크 티",        42900, ["가을", "겨울", "라이더", "외출"], 5, 13),
    ("스프라이트 포차코 그린 티",   23900, ["가을", "겨울", "가디건", "데일리"], 2, 7),  # 25
]

CATS = [
    # cloth26
    ("스프라이트 포차코 베이직 티",          14900, ["겨울", "실내", "방한", "니트"], None, None),
    ("옐로우 스프라이트 티",         7900, ["실내", "리본", "데일리"], None, None),
    ("그린 스프라이트 티",      18900, ["봄", "실내", "이벤트"], None, None),
    ("블루 스프라이트 티",          17900, ["겨울", "실내", "플리스"], None, None),
    ("퍼플 스프라이트 티",          13900, ["가을", "할로윈", "코스튬", "이벤트"], None, None),  # 30
    ("부드러운 그린 코튼 티",   11900, ["봄", "여름", "실내", "데일리"], None, None),
    ("부드러운 악어 코튼 티",    15900, ["겨울", "크리스마스", "코스튬", "이벤트"], None, None),
    ("코튼 그린 데일리 후드티",            12900, ["봄", "실내", "이벤트"], None, None),
    ("코튼 블루 데일리 후드티",        16900, ["봄", "가을", "캐릭터", "데일리"], None, None),
    ("부드러운 블루 코튼 티",          13900, ["가을", "겨울", "실내", "데일리"], None, None),  # 35
    ("블루 원피스",            10900, ["여름", "쿨링", "통풍"], None, None),
    ("데일리 블루 면티",            12900, ["봄", "여름", "실내", "데일리"], None, None),
    ("데일리 핑크 면티",          24900, ["겨울", "이벤트", "벨벳"], None, None),
    ("데일리 화이트 면티",             8900, ["겨울", "크리스마스", "이벤트"], None, None),
    ("유니버시티 네이비 후드티",             19900, ["봄", "여름", "여아", "원피스"], None, None),  # 40
    ("YALE 블랙 후드티",            16900, ["겨울", "실내", "누비"], None, None),
    ("귀여운 프린팅 기본 면티",          13900, ["가을", "코스튬", "이벤트"], None, None),
    ("귀여운 프린팅 옐로우 면티",        11900, ["봄", "여름", "실내", "데일리"], None, None),
    ("귀여운 프린팅 그린 면티",           17900, ["봄", "캐릭터", "점프수트"], None, None),
    ("외출용 방한 아이보리 방풍복",          14900, ["봄", "캐릭터", "후드"], None, None),       # 45
    ("외출용 방한 올리브 방풍복",    15900, ["겨울", "크리스마스", "코스튬"], None, None),
    ("YALE 아이보리 면티",      22900, ["겨울", "실내", "니트", "고급"], None, None),
    ("데일리 핑크 후드티",          27900, ["설날", "한복", "이벤트"], None, None),
    ("기본 흰색 면 후드",         12900, ["봄", "가을", "실내", "데일리"], None, None),
    ("프린팅 블루 원피스",     6900, ["여름", "패션", "악세사리"], None, None),     # 50
]


def main():
    init_db()
    db = SessionLocal()
    try:
        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        added, skipped = 0, []

        def add(idx_start: int, items, species: str):
            nonlocal added
            for offset, (name, price, tags, smin, smax) in enumerate(items):
                fname = f"cloth{idx_start + offset}.jpg"
                local_path = UPLOAD_DIR / fname
                key = f"uploads/products/{fname}"
                if not local_path.exists():
                    skipped.append(str(local_path))
                    continue
                # 저장소 백엔드(local/gcs)에 따라 자동 분기.
                #   - local: 이미 같은 경로에 있으므로 storage.save 가 no-op이지만
                #            일관성을 위해 byte 재기록.
                #   - gcs:   해당 경로로 버킷에 업로드.
                if not storage.exists(key):
                    mime, _ = mimetypes.guess_type(str(local_path))
                    storage.save(key, local_path.read_bytes(), mime or "image/jpeg")
                p = Product(
                    name=name,
                    species=species,
                    category="옷",
                    price=int(price),
                    image_path=key,
                    tags=",".join(tags) or None,
                    size_min_kg=smin,
                    size_max_kg=smax,
                    is_active=True,
                )
                db.add(p)
                added += 1

        add(1, DOGS, "dog")        # cloth1..25
        add(26, CATS, "cat")       # cloth26..50
        db.commit()

        print(f"✅ 추가: {added}개")
        print(f"   - 강아지 {len(DOGS)}개, 고양이 {len(CATS)}개")
        if skipped:
            print(f"⚠️  사진 못 찾아서 건너뜀: {len(skipped)}개")
            for s in skipped[:10]:
                print(f"    - {s}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
