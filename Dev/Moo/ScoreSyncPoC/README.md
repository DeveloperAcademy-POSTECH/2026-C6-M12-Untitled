# 악보 인식 테스트 (ScoreSyncPoC)

PDF 악보에서 **System(한 줄)**과 **마디 위치**를 CV(컴퓨터 비전)로 자동 검출해서
화면에 오버레이로 보여주는 테스트 앱입니다. 음표는 읽지 않고, "몇 번째 System의
몇 번째 마디가 화면 어디에 있는가"만 찾습니다.

## 구성

- `ScoreDetectCore/` — 검출 로직만 들어있는 Swift Package (앱과 분리, 유닛 테스트 포함)
  - `Sources/ScoreDetectCore/GrayscaleImage.swift` — 8bit 흑백 픽셀 버퍼
  - `Sources/ScoreDetectCore/PDFPageRasterizer.swift` — PDF 페이지 → 이미지 변환
  - `Sources/ScoreDetectCore/OtsuThreshold.swift` — 페이지별 자동 이진화 임계값 계산
  - `Sources/ScoreDetectCore/RunLengthCalibrator.swift` — 오선 두께/간격 자동 추정
  - `Sources/ScoreDetectCore/SkewCorrector.swift` — 살짝 기울어진 페이지 자동 보정
  - `Sources/ScoreDetectCore/StaffLineDetector.swift` — 오선 검출 → Staff → System 묶기
  - `Sources/ScoreDetectCore/BarlineDetector.swift` — 마디선(barline) 검출
  - `Sources/ScoreDetectCore/ScoreDetector.swift` — 위 파일들을 엮는 진입점
  - `Sources/ScoreDetectCore/Models.swift` — 결과 모델 (Codable, JSON 내보내기용)
  - `Sources/ScoreDetectCore/DetectionParameters.swift` — 튜닝 가능한 임계값들
  - `Tests/ScoreDetectCoreTests/` — 합성 이미지로 만든 유닛 테스트 7개 파일
- `App/` — SwiftUI 화면 5개 파일 (새 Xcode 프로젝트에 추가해서 사용)

## 이 환경에서 못 한 것

지금 작업한 환경(클라우드 컨테이너 + Mac에 연결된 원격 셸)에는 Xcode 툴체인이
없어서 **직접 빌드/실행/테스트를 확인하지 못했습니다.** `.xcodeproj`도 잘못
만들면 열리지 않을 위험이 있어서 손으로 만들지 않았고, 대신 아래 순서대로
Xcode에서 직접 새 프로젝트를 만들고 이 파일들을 추가하는 방식을 권해요.
코드는 꼼꼼히 검토했지만, 처음 빌드에서 사소한 오류가 날 수 있으니 그 경우
알려주시면 바로 고칠게요. 자동 보정·기울기 보정·PDF 회전 처리 로직도
마찬가지로 아직 실제 PDF로 검증하지 못했습니다 — 특히 PDF 회전 처리는
`CGPDFPageGetDrawingTransform`의 문서화된 동작에 근거해서 작성했지만,
실제 회전된 PDF로 눈으로 확인하기 전까지는 100% 확신할 수 없어요.

## Xcode에서 여는 순서

1. Xcode에서 **File → New → Project → iOS → App** 생성
   - Product Name: `ScoreSyncPoC` (원하는 이름으로 해도 됨)
   - Interface: **SwiftUI**, Language: **Swift**
   - 저장 위치는 아무 곳이나 상관없음 (이 폴더를 덮어쓸 필요 없음)

2. **File → Add Package Dependencies… → Add Local…** 선택 후
   `Documents/ScoreSyncPoC/ScoreDetectCore` 폴더를 선택해서 로컬 패키지로 추가.
   앱 타겟(`ScoreSyncPoC`)에 `ScoreDetectCore` 라이브러리를 연결.

3. `Documents/ScoreSyncPoC/App/` 안의 5개 파일을
   - `ScoreSyncPoCApp.swift`
   - `ContentView.swift`
   - `ScorePageOverlayView.swift`
   - `DetectionControlsView.swift`
   - `JSONFileDocument.swift`

   Xcode 프로젝트 네비게이터로 드래그해서 추가 (**Copy items if needed** 체크).
   새 프로젝트가 기본으로 만든 `ScoreSyncPoCApp.swift` / `ContentView.swift`는
   덮어쓰기(또는 기존 것 삭제 후 추가).

4. 실기기 또는 시뮬레이터 선택 후 빌드 & 실행.

5. 우측 상단 `+` 아이콘으로 PDF 악보 파일을 열면 자동으로 1페이지를 분석해서
   - 파란 테두리: 인식된 System(한 줄)
   - 초록 테두리: 인식된 마디
   를 원본 이미지 위에 그려줍니다. 마디를 탭하면 빨간색으로 선택되고
   `System N - Measure M` 라벨이 뜹니다. 그 아래에는 이번 페이지에서 실제로
   쓰인 임계값/추정 오선 두께·간격이 한 줄로 표시됩니다.

6. 하단 슬라이더 패널에서 임계값을 조절하고 **"다시 인식하기"**를 눌러 결과를
   비교해볼 수 있어요 (슬라이더를 움직이는 것만으로는 재분석하지 않음 — 전체
   페이지 재계산은 비용이 있어서 버튼으로만 트리거하게 만들었어요). 맨 위
   **"자동 보정 사용"** 토글을 끄면 예전처럼 슬라이더 값을 그대로 쓰고,
   켜두면 어둡기 임계값 슬라이더는 무시되고 페이지마다 자동 계산됩니다.
   그 아래 **"기울기 자동 보정"** 토글은 스캔/사진 악보가 살짝 기울어져
   있을 때 보정을 시도할지 여부이고, 옆의 "최대 보정 각도" 슬라이더로 얼마나
   과감하게 보정할지 범위를 정합니다.

7. 우측 상단 공유 아이콘으로 현재까지 분석한 모든 페이지 결과를 JSON으로
   내보낼 수 있습니다 (`Models.swift`의 `DetectedScore` 구조 그대로).

## ScoreDetectCore만 따로 테스트하기

Xcode에서 `Documents/ScoreSyncPoC/ScoreDetectCore` 폴더를 **Open**으로 직접 열면
(프로젝트가 아니라 패키지 자체를 여는 것) `Cmd+U`로 유닛 테스트를 바로 돌릴 수
있어요. 합성 이미지(코드로 그린 흰 배경 + 검은 선)만으로 오선/마디선 검출과
자동 보정/기울기 보정 로직을 검증합니다 (`StaffLineDetectorTests`,
`BarlineDetectorTests`, `OtsuThresholdTests`, `RunLengthCalibratorTests`,
`SkewCorrectorTests`).

## 알고리즘 요약

1. PDF 페이지를 `renderScale`배 해상도로 흑백 이미지로 렌더링 (페이지의 회전
   속성(`/Rotate`)을 반영해서 렌더링하고, 페이지가 지나치게 크거나 배율이 높아도
   메모리를 과도하게 쓰지 않도록 해상도 상한을 둠 — 아래 "이번에 추가한 견고성
   개선" 참고)
2. **(자동 보정 켜진 경우)** Otsu's method로 이 페이지에 맞는 이진화 임계값을 계산
3. **(기울기 보정 켜진 경우)** 오선이 최대한 수평이 되도록 작은 회전 각도(기본
   최대 ±5°)를 찾아서 보정 (아래 "이번에 추가한 견고성 개선" 참고)
4. 오선 두께·간격을 자동 추정 (자동 보정 켜진 경우, 아래 "이전에 추가한 자동
   보정" 참고). 자동 보정이 꺼져 있으면 2~4단계 없이 슬라이더로 지정한 고정값을
   그대로 사용.
5. 가로 전체 폭 중 어두운 픽셀 비율이 `minStaffLineDarkRatio` 이상인 행을
   오선 후보로 판정 → 연속된 행을 하나의 선으로 병합
6. 5개의 선이 `staffSpacingTolerance` 이내로 균등 간격이고, (자동 보정 중이면)
   추정된 오선 간격과도 크게 다르지 않으면 하나의 Staff로 인정
7. 인접한 Staff끼리 간격이 `systemGroupingMaxGapInStaffSpaces`(오선 간격의 배수)
   이내면 하나의 System(예: 피아노 그랜드 스태프, 여러 파트가 묶인 시스템)으로 병합
8. System 안에서, 오선 사이 "빈 칸" 행들만 따로 보고 그 칸에서 어두운 비율이
   `minBarlineDarkRatio` 이상인 열을 마디선 후보로 판정 (오선 자체는 항상
   어두우므로 오선 행을 빼고 봐야 마디선만 걸러짐). 자동 보정 중이면 후보의
   가로 폭이 추정 오선 두께의 `barlineMaxThicknessMultiplier`배보다 넓으면
   버림 (코드·빔 등 굵은 블록 오탐 제거, 아래 참고)
9. 마디선 x좌표들 사이 구간을 마디 영역으로 저장 (`minMeasureWidthPx`보다
   좁으면 노이즈로 버림)

## 이번에 추가한 자동 보정 (정확도 개선)

기존 검출 로직과 비슷한 전통적 CV 기반(딥러닝 아님) 악보 인식 논문/구현을
조사해서 두 가지 잘 알려진 기법을 참고해 반영했습니다.

- **Otsu's method (자동 이진화 임계값)** — 페이지마다 스캔 상태·대비가 달라서
  하나의 고정 `darkPixelThreshold`(기존 기본값 128)로는 어떤 페이지는 너무
  약하게, 어떤 페이지는 너무 세게 어두운 픽셀을 잡을 수 있습니다. Otsu's
  method는 픽셀 값 히스토그램을 두 그룹(배경/잉크)으로 나눴을 때 그룹 간
  분산이 최대가 되는 지점을 임계값으로 자동 선택하는 표준 기법으로, 이번에
  `OtsuThreshold.swift`로 구현해서 페이지마다 새로 계산하도록 했습니다.
- **Cardoso & Rebelo (2010), "Robust Staffline Thickness and Distance
  Estimation in Binary and Gray-Level Music Scores" (ICPR 2010)** — 오선
  두께와 오선 사이 간격을 자동으로 추정하는 방법입니다. 단순히 "검은 픽셀이
  연속된 길이(두께 후보)"와 "흰 픽셀이 연속된 길이(간격 후보)"를 각각
  따로 최빈값을 구하면 음표머리·가사·잡음 때문에 흔들리기 쉬운데, 이 논문은
  "오선 한 줄 + 바로 아래 빈 칸"을 한 쌍으로 보고 그 **합(두께+간격)**의
  최빈값을 먼저 찾은 다음, 그 합을 만드는 조합 중 가장 흔한 (두께, 간격)
  쌍을 실제 추정값으로 쓰는 방식이라 훨씬 안정적입니다. `RunLengthCalibrator.swift`
  로 구현했고, 여기서 나온 간격 추정값은 Staff 판정(`groupIntoStaves`)의
  교차 검증에, 두께 추정값은 마디선 폭 필터링에 사용됩니다.
- **마디선 폭 필터링** — 위 두 기법으로 얻은 오선 두께 추정값을 이용해,
  "빈 칸" 행에서 어두운 비율이 높다고 다 마디선으로 보지 않고 가로 폭이
  오선 두께의 일정 배수(`barlineMaxThicknessMultiplier`, 기본 4배)보다
  넓은 후보는 버립니다. 코드(화음)·빔·못갖춘마디 다이내믹 기호처럼 굵고 넓은
  검은 덩어리를 걸러내는 데 도움이 됩니다. 다만 **홑대 줄기(stem) 하나는
  오선 두께와 폭이 비슷해서 이 필터로는 구분되지 않는다는 한계는 그대로
  남아 있습니다** — 아래 "알려진 한계" 참고.

추가된 파라미터 (`DetectionParameters`):
- `useAutoCalibration` (기본 `true`) — 켜져 있으면 Otsu 임계값 + 오선 두께/간격
  자동 추정을 사용하고, 슬라이더의 수동 `darkPixelThreshold`는 무시됩니다.
- `barlineMaxThicknessMultiplier` (기본 `4.0`) — 마디선 후보로 인정할 최대
  가로 폭을, 추정된 오선 두께의 몇 배까지 허용할지.
- `useSkewCorrection` (기본 `true`) — 켜져 있으면 기울기 자동 보정을 시도합니다.
- `maxSkewCorrectionDegrees` (기본 `5.0`) — 기울기 보정이 찾을 수 있는 최대 각도.

`DetectedPage`에도 필드가 추가되어 이 페이지에서 실제로 쓰인 임계값·추정치·
보정 각도를 JSON으로도 확인할 수 있습니다: `usedDarkThreshold`,
`estimatedStaffLineThicknessPx`, `estimatedStaffSpacePx`,
`appliedSkewAngleDegrees`.

## 이번에 추가한 견고성 개선 (예외 처리 포함)

정확도 개선과 별개로, 실제 사용자들이 올릴 법한 "정상 경로를 벗어난" 입력들에
대비해 아래를 추가/수정했습니다.

- **PDF 페이지 회전(`/Rotate`) 처리 버그 수정**: 기존 코드는 `PDFPage.bounds(for:)`로
  얻은 원본(회전 반영 전) 가로/세로로 캔버스를 만들고 있었어요. 만약 스캔 과정에서
  페이지가 90°/270°로 회전 저장된 PDF가 들어오면(흔한 케이스입니다), 그림이
  찌그러진 채로 렌더링되고 이후 모든 행/열 기반 검출이 의미 없어졌을 거예요.
  `CGPDFPageGetDrawingTransform`(Apple이 문서화한 정식 방법)을 써서 회전을
  반영한 가로/세로로 캔버스를 만들고 정확히 그리도록 `PDFPageRasterizer`를
  다시 작성했습니다.
- **메모리 안전 상한**: `renderScale` 슬라이더를 높게(5배) 두고 페이지가 유난히
  큰 PDF를 열면, 예전 코드는 요청한 그대로 거대한 픽셀 버퍼를 할당하려고
  시도했을 거예요. 이제 전체 픽셀 수가 약 4천만 픽셀을 넘지 않도록 필요하면
  실제 렌더 배율을 자동으로 낮춰서, 극단적인 입력에서도 크래시 대신 해상도만
  약간 낮아지도록 했습니다.
- **기울기(skew) 자동 보정** (`SkewCorrector.swift`, 새 파일): "스캔/사진
  악보에는 약함"이라는 기존 한계 중 기울어짐 부분을 부분적으로 해결합니다.
  여러 후보 각도(기본 ±5° 범위)로 이미지를 돌려보면서, 오선 행이 가장 뚜렷하게
  "어두움/밝음"으로 갈리는 각도를 찾는 표준적인 투영 프로파일(projection
  profile) 기법입니다. 이미 똑바른 페이지는 건드리지 않도록 보수적으로
  동작합니다 (관련 유닛 테스트 3개 추가).
- **암호로 보호된 PDF 처리**: `PDFDocument(url:)`는 암호로 잠긴 PDF도 `nil`이
  아닌 값을 반환하지만 페이지 내용은 비어있어요. 예전에는 이 경우 "빈 페이지"로
  처리되어 사용자가 왜 아무것도 안 잡히는지 알 수 없었는데, 이제 가져오기
  단계에서 `isLocked`를 확인해서 "암호로 보호된 PDF예요"라고 바로 알려줍니다.
- **오선을 하나도 못 찾은 페이지**: 표지처럼 악보가 없는 페이지를 열어도
  크래시 없이 "System 0개"로 정상 처리되긴 했지만, 사용자 입장에서는 이게
  버그인지 정상인지 구분이 안 됐을 거예요. 이제 이 경우 상태 메시지에
  "오선을 찾지 못했어요"라고 명시적으로 표시합니다.
- **오래된 JSON 내보내기 파일과의 호환성**: `DetectionParameters`에 새 필드가
  생길 때마다(이번엔 `useSkewCorrection`, `maxSkewCorrectionDegrees`) 예전에
  내보낸 JSON을 다시 읽어들이면 필드가 없어서 디코딩이 실패할 수 있었는데,
  누락된 필드는 기본값으로 채우는 커스텀 `Codable` 구현으로 바꿔서 앞으로도
  이런 이유로 깨지지 않게 했습니다.
- **자잘한 경계 조건**: 빈 이미지(가로/세로 0)로 끝나는 극단적인 경우, System의
  세로 범위가 뒤집힌 경우 등 몇 군데에 방어적 가드를 추가했습니다.

## 알려진 한계 (README에 정직하게 남겨둠)

- **홑대 줄기(stem) 오탐은 여전히 남아있음**: 이번 마디선 폭 필터링은 코드·빔처럼
  "넓은" 오탐은 잘 걸러내지만, 음표 줄기 하나는 폭이 오선 두께와 비슷해서
  여전히 마디선으로 오인될 수 있어요. 실제 악보로 테스트하면서
  `minBarlineDarkRatio`를 올리거나(마디선은 보통 오선 전체 높이를 관통하지만
  줄기는 보통 한쪽에 치우쳐 있어서 여러 Staff를 걸치는 System 단위로 보면
  구분이 쉬워짐) 조정이 필요할 수 있습니다.
- **자동 보정은 오선이 페이지에 충분히 반복돼야 안정적**: `RunLengthCalibrator`는
  페이지 안에서 "오선+간격" 패턴이 가장 흔한 세로 패턴이라는 가정에
  기대는 방식이라, 오선이 거의 없거나 매우 짧은 페이지(예: 표지)에서는
  추정에 실패할 수 있고, 이 경우 자동 보정 없이 기존 로직(고정 임계값 128,
  간격 조건 없이 내부 균등성만 확인)으로 자연히 폴백됩니다.
- **반복기호·D.S.·Coda 등은 인식하지 않음**: 이 PoC는 순수 구조(선) 검출이라
  음악적 의미는 전혀 모릅니다. 이후 계획서에서 다룬 대로 반복 구조는 별도
  UI(수동 편집)나 OMR이 필요해요.
- **스캔/사진 악보에는 여전히 약함 (기울어짐은 부분 개선됨)**: 살짝 기울어진
  정도(기본 최대 ±5°)는 `SkewCorrector`가 보정을 시도하지만, 그림자·구겨짐·
  원근 왜곡(perspective distortion, 카메라를 정면이 아니라 비스듬히 찍은 경우)
  보정은 없어서, 지금도 PDF에서 바로 뽑은 깔끔한 페이지 기준으로 테스트하는
  걸 권장합니다.
- **첫/마지막 조각도 "마디"로 포함**: 첫 번째 마디선 앞(보통 clef/조표 영역)과
  마지막 마디선 뒤 영역도 하나의 측정 구간으로 만들어요. 실제 사용할 땐
  이 두 조각을 걸러내는 로직이 필요할 수 있어요.
- **JSON 좌표계는 래스터 이미지 픽셀 기준**(왼쪽 위 원점, y 아래로 증가)이고
  `renderScale`에 따라 절대값이 달라집니다. 나중에 음원 Bar와 연결할 때는
  이 좌표를 그대로 쓰기보다 "N번째 System의 M번째 마디"라는 순서 정보를
  주로 활용하는 걸 권해요.

## 다음 단계 (참고)

이번 PoC는 "PDF에서 마디 위치 찾기"까지입니다. 이후 단계는 이전에 정리한
계획서(`공연자 지원 챌린지` 프로젝트 문서)의 순서를 따르면 됩니다:
마디 위치 확정 → 사용자가 수정할 수 있는 에디터 → Apple Music Understanding의
Bar 시간과 순서대로 매핑 → 현재 재생 위치에 맞춰 마디 하이라이트.
