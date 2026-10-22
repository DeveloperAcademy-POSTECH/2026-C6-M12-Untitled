# Syncy

밴드 합주 iPad 앱. 곡을 파트별로 분리해 재생하고, 트랙 줄에 핀을 꽂아 글과 녹음으로 피드백을 주고받는다.
SwiftUI + TCA(The Composable Architecture) 1.26. Xcode 프로젝트는 `Syncy/Syncy.xcodeproj`.

## 기준 문서

설계의 기준은 피그마 '뽀삐뽀삐' 보드와, 그 내용을 글로 옮긴 `docs/ARCHITECTURE.md`다. 코드와 설계가 다르면 설계를 따른다. 설계가 틀렸다고 보이면 고치기 전에 팀에 먼저 알린다.
- 개요도 (구조 · 연결 표): https://www.figma.com/board/6r8nEepkPqBkGNS7e9TBXy?node-id=329-2361
- 클래스 다이어그램 (정리본): https://www.figma.com/board/6r8nEepkPqBkGNS7e9TBXy?node-id=332-2453
- 시퀀스 다이어그램 (S1~S5): https://www.figma.com/board/6r8nEepkPqBkGNS7e9TBXy?node-id=355-2451
- Client 반환 타입 · JobStatus: https://www.figma.com/board/6r8nEepkPqBkGNS7e9TBXy?node-id=473-3012

## 빌드

```bash
xcodebuild -project Syncy/Syncy.xcodeproj -scheme Syncy -destination 'generic/platform=iOS Simulator' build
```

배포 대상은 iOS 27.0이다. 시뮬레이터에서 실행하려면 iOS 27 시뮬레이터가 필요하다.

## 구조

- `AppFeature`(Super Reducer)가 자식 4개를 `Scope`로 조립한다: Session · Sync · Feedback · Player.
- `PracticeFeature`는 `PlayerFeature`의 자식이다. 화면도 `PlayerView` 안의 `PracticePanel`이다.
- Feature끼리는 서로 직접 부르지 않는다. 주고받는 방법은 셋뿐이다.
  1. 알림: 자식이 `delegate`로 알리고, `AppFeature`가 연결 표대로 받는 Feature에 전달한다.
  2. 공유 값: `@Shared` `pinDraft` · `activePin` · `patches`. 키는 `Models/SharedKeys.swift`에만 둔다.
  3. 부모와 자식: Player와 Practice는 직접 주고받는다.
- 새 연결이 필요하면 팀과 정한 뒤 `AppFeature`와 피그마 개요도의 연결 표를 함께 고친다.

## 담당

| 담당 | Feature | Client |
|---|---|---|
| Martin | `SessionFeature` · `SyncFeature` | `SeparationClient` · `SongCacheClient` · `SyncClient` |
| Anna | `PlayerFeature` (`PracticeFeature` 포함) | `AudioClient` |
| Moo | `FeedbackFeature` | `StorageClient` (Sync도 받은 녹음 저장에 쓴다) |
| Martin (공용) | `App/` (`AppFeature` 연결 표 · `AppView`) · `Models/` · `Core/` | `ProfileClient` |

작업하는 사람이 누구인지는 각자의 `CLAUDE.local.md`(git에 올리지 않음)에 적는다. 예: `이 컴퓨터의 사용자는 Anna다.`

## 코드 규칙

- `@Reducer` + `@ObservableState`. State는 `Equatable`, Action은 `Sendable`.
- Action 이름: 사용자 행동은 `…Tapped` · `…Changed`, 바깥 일의 결과는 `…Response`, 부모에게 알리는 건 `delegate(Delegate)` 안.
- 바깥 일(서버 · 오디오 · 파일)은 Client로만 한다. Reducer에서 `URLSession`, `Date()`, `UUID()`, `Task.sleep`을 직접 부르지 않고 `@Dependency`(`\.continuousClock`, `\.date`, `\.uuid`)를 쓴다.
- 같은 정보는 한 곳에만 저장하고, 다른 Feature는 받아서 쓴다. 곡 BPM은 `Song.bpm`, 이 기기의 사람(`me`)은 `AppFeature`가 정해서 내려준다.
- 시간은 저장 · 전달 모두 초(`TimeInterval`)다. 마디 · 박은 화면 표시용이고 `BeatGrid`로 바꾼다.
- 재생 위치처럼 초당 여러 번 바뀌는 값은 State에 넣지 않는다. 화면이 `AudioClient.position()`을 직접 구독한다.
- 오래 도는 Effect는 `cancellable(id:)`를 붙인다.

## Client 규칙

- `○○Client`: TCA용 함수 목록(`@DependencyClient` 구조체) + `liveValue` · `previewValue` · `testValue`. 프로토콜은 쓰지 않는다.
- `○○Service`: 실제 일을 하는 코드(HTTP · AVAudioEngine · 파일). TCA를 모른다. `liveValue`는 Service를 부르기만 한다.
- 실제 일이 긴 Client는 `Dependencies/○○Client/` 폴더에 Client와 Service를 나눠 둔다. 짧은 Client는 파일 하나.
- Client의 함수 모양(받는 것 · 돌려주는 것)은 여러 Feature가 같이 쓴다. 바꾸기 전에 이슈로 먼저 이야기한다.

## 폴더

| 이런 것은 | 여기에 |
|---|---|
| `AppFeature` · `AppView` · `@main` | `App/` |
| Feature의 Reducer · 화면 · 그 Feature만 쓰는 타입 | `Features/○○Feature/` (자식 Feature는 부모 폴더 안) |
| 두 Feature 이상이 쓰는 데이터, `@Shared` 값 | `Models/` |
| Client · Service, 그 Client만 쓰는 타입(`JobStatus`, `AudioEvent`) | `Dependencies/` |
| 여러 화면이 같이 쓰는 UI · 색 · 상수 · 확장 | `Core/` (Components · Theme · Constants · Extensions) |
| 이미지 · 소리 | `Resources/` |

## 기능 규칙 (핀 대화)

- 모든 밴드원은 같은 권한이다. `Person`은 id · 이름 · 맡은 파트(`SessionID`)다.
- 핀 대화는 글과 녹음 답만 있다. 녹음 답은 누구나, 횟수 제한 없이 단다.
- 패치 등록은 핀이 꽂힌 파트만 한다. 핀 삭제는 작성자만 한다.
- 패치를 재생에 켜고 끄는 건 Player가 `@Shared patches`의 `isAdopted`를 보고 직접 한다.

## 테스트

- 테스트 타깃은 아직 없다. 테스트를 만들거나 돌리려 하지 않는다.
- 테스트 타깃을 만든 뒤에는 Reducer 흐름을 `TestStore`로 검증하고, Client는 `testValue`나 `withDependencies`로 바꿔 끼운다.
- 녹음 · 마이크 권한 · 오디오 인터럽트는 시뮬레이터가 아니라 실기기에서 확인한다.

## Git

- 이슈 · 브랜치 · 커밋 · PR 규칙은 `README.md`를 따른다.
- 푸시하기 전에 `develop`의 최신 내용을 받는다. `develop`과 `main`에 직접 푸시하지 않는다.
- 커밋 · 푸시 · PR은 사람이 요청할 때만 한다.

## 함께 작업할 때

- 내 담당이 아닌 파일과 여러 사람이 같이 고치는 파일(`AppFeature.swift`의 연결 표, `Models/`, `SharedKeys.swift`)은 고치기 전에 이슈로 먼저 이야기한다.
- 파일을 추가할 때는 Xcode의 폴더(파란 폴더) 방식을 쓴다. 그룹으로 추가하면 `project.pbxproj` 충돌이 늘어난다.
- 설계를 바꾸는 결정(연결 추가, Client 함수 모양, 기능 규칙)은 팀이 정한다. 에이전트가 혼자 바꾸지 않는다.

## 학습 목적

이 프로젝트는 TCA 학습이 목적이다.
- 요청이 없으면 Reducer 로직을 대신 작성하지 않는다. 설명 · 리뷰 · 방향 제시를 먼저 한다.
- 코드를 쓸 때는 왜 그렇게 썼는지 TCA 개념(State · Action · Effect · Dependency · Scope · delegate)으로 설명한다.
