# 공식 가이드라인 PDF

저작권 문제로 PDF 본문을 레포지토리에 포함하지 않습니다.
직접 다운로드해 이 폴더에 두고 `manifest.yaml` 을 작성한 뒤 시드 스크립트를 실행하세요.

## 추천 출처

| 영역 | 출판 | 제목 | 비고 |
|---|---|---|---|
| 백신 (개+고양이) | WSAVA | 2024 Guidelines for the Vaccination of Dogs and Cats | 글로벌 표준 |
| 백신 (개) | AAHA | 2022 Canine Vaccination Guidelines (2024 update) | Core/Non-core 표 포함 |
| 백신 (고양이) | AAHA/AAFP | 2020 Feline Vaccination Guidelines | Feline Vaccination Table 포함 |
| 영양/급여 | WSAVA GNC | Global Nutrition Guidelines (2011, Toolkit 2021) | 권장 칼로리·BCS 도구 |
| 발달/건강검진 (개) | AAHA | 2019 Canine Life Stage Guidelines + Checklists | 생애주기별 체크리스트 |
| 발달/건강검진 (고양이) | AAHA/AAFP | 2021 Feline Life Stage Guidelines | |
| 구충/기생충 | CAPC | General Guidelines + Quick Product Reference | 월령별 구충 |
| 중성화 시기 | AAHA / Fix Felines by Five | Canine Life Stage (개) / 5개월 이전 중성화 (고양이) | |

## 매니페스트 작성

`manifest.example.yaml` 를 `manifest.yaml` 로 복사한 뒤 본인이 보유한 파일에 맞춰 항목을 수정/삭제하세요. 매니페스트에 등록된 파일만 적재됩니다.

## 적재

```bash
python -m scripts.seed_knowledge
```

`.md` 시드 + PDF 가 동일 ChromaDB 컬렉션에 들어갑니다. 가이드 생성 시 두 출처를 함께 검색하지만, 캘린더 이벤트는 구조화된 `.md` 메타로만 산출됩니다(환각 방지).
