# watchOS 디자인 시스템 (CoreWatchDesignSystem)

> 워치 화면(#1206~#1209·#1215)이 사용하는 토큰·표면·컴포넌트 레퍼런스와 **Glass 허용/금지 매트릭스**.
> 핵심 요약은 `CLAUDE.md` 참고. iOS 디자인 시스템은 `docs/claude/design-system.md` 참고 — 워치는 그 규칙을 따르지 않는다.

- 작성자: euijjang97
- 기준 코드:
  - `UMCApp/Core/WatchDesignSystem/Project.swift`
  - `UMCApp/Core/WatchDesignSystem/Sources/Tokens/WatchColor.swift`
  - `UMCApp/Core/WatchDesignSystem/Sources/Tokens/WatchTypography.swift`
  - `UMCApp/Core/WatchDesignSystem/Sources/Tokens/WatchLayout.swift`
  - `UMCApp/Core/WatchDesignSystem/Sources/Surfaces/WatchSurface.swift`
  - `UMCApp/Core/WatchDesignSystem/Sources/Components/WatchActionButton.swift`
  - `UMCApp/Core/WatchDesignSystem/Sources/Components/WatchStatusBadge.swift`
  - `UMCApp/Core/WatchDesignSystem/Tests/WatchColorTokenTests.swift`
  - `UMCApp/UMCWatchApp/Project.swift`
  - `UMCApp/UMCWatchApp/Sources/Fallback/WatchFallbackReason.swift`
  - `UMCApp/UMCWatchApp/Sources/Fallback/WatchFallbackPresentation.swift`
  - `UMCApp/UMCWatchApp/Sources/Fallback/WatchFallbackScene.swift`
  - `UMCApp/UMCWatchApp/Sources/Fallback/WatchFallbackView.swift`
  - `UMCApp/UMCWatchApp/Sources/Fallback/WatchOfflineQueue.swift`
  - `UMCApp/UMCWatchApp/Sources/Fallback/WatchMandatoryNotice.swift`
  - `UMCApp/UMCWatchApp/Sources/Routing/WatchRoute.swift`
  - `UMCApp/UMCWatchApp/Sources/Routing/WatchRootView.swift`
  - `UMCApp/UMCWatchApp/Tests/WatchFallbackReasonTests.swift`

## 1) 모듈 분리 근거 — 왜 `CoreDesignSystem` 확장이 아닌가

`CoreDesignSystem` 을 watchOS 로 넓히지 않고 `Core/WatchDesignSystem` 을 신설했다. 근거는 매니페스트 주석에 원문이 있다 (`UMCApp/Core/WatchDesignSystem/Project.swift:4-20`).

| 이유 | 내용 |
|------|------|
| **토큰 값이 다르다 (핵심 함정)** | iOS `Colors.xcassets` 의 colorset 은 light/dark 를 함께 갖는데 **watchOS 는 항상 dark 로 해석**한다. 같은 카탈로그를 워치 타겟에 링크하면 브랜드 인디고가 스펙값 `#4869F0` 이 아니라 dark 값 `#4264F0` 으로 나온다 (`orange500` → `#FF6C0F`, `grey400` → `#7C8792` 도 동일). 자산 카탈로그를 공유할 수 없는 실제 이유다. |
| **타이포가 다르다** | 워치 스펙은 시스템 폰트(SF) 기반 — Pretendard `.otf` 3종이 필요 없다. `CoreDesignSystem` 을 링크하면 안 쓰는 폰트 리소스가 워치 번들에 실린다. |
| **컴포넌트 규칙이 반대다** | iOS 는 Glass 를 카드 배경까지 쓰지만 워치는 컨트롤에만 쓴다 (§4). iOS `PrimaryButtonStyle` 의 `height: 44` 고정 같은 폰 전제 API 가 워치 자동완성에 뜨는 것도 막는다. |

### 1-1) destinations 가 `[.iPhone, .appleWatch]` 인 이유

순전히 **테스트 실행 경로** 때문이다 (`Project.swift:16-19`). Makefile 기본 `DESTINATION` 이 iOS 시뮬레이터라, 워치 전용으로 잡으면 `make test SCHEME=CoreWatchDesignSystem` 이 기본값으로 돌지 않는다. 이 모듈은 watchOS 전용 API 를 쓰지 않아 iOS 에서도 그대로 컴파일된다. 멀티플랫폼 Core 모듈 선례는 `Core/WatchConnectivity`.

- **iOS 화면은 이 모듈을 쓰지 않는다** — iOS 는 `CoreDesignSystem`. 소비자는 `UMCWatchApp` 뿐이다 (`UMCApp/UMCWatchApp/Project.swift:9`).
- 리소스·의존성 0 (`dependencies: []`, asset catalog 없음). #1215 워치 위젯 익스텐션이 생기면 같은 한 줄로 링크한다.

## 2) 색 토큰 (`WatchColor`) — 단일 출처와 드리프트 가드

### 2-1) Swift sRGB 리터럴이 워치 쪽 원본이다

asset catalog 없이 `WatchColorHex`(internal, `WatchColor.swift:75-93`)의 `0xRRGGBB` 리터럴이 유일한 값 출처다. 워치는 appearance 분기가 없어(항상 dark) 한 벌로 충분하고, 헥스값이 코드에 그대로 보여 grep·리뷰가 된다.

| 그룹 | 토큰 | 값 | 용도 |
|------|------|-----|------|
| 배경 | `screen` | `#000000` | 화면 전체 배경. OLED 픽셀 소등(배터리·번인) |
| | `cardBackground` / `cardBorder` | `#16181C` / `#2A2D34` | 일반 카드 — 불투명 solid |
| | `heroBackground` / `heroBorder` | `#1B2140` / 인디고 45% | Hero(대표 지표) 카드 |
| | `dangerBackground` / `dangerBorder` | `#241416` / 에러 레드 40% | 위험·파괴적 맥락 카드 |
| 브랜드 | `brandPrimary` | `#4869F0` | CTA tint·active·Hero 보더 (iOS `indigo500`) |
| | `brandPrimaryHighlight` | `#6683FF` | 다크 카드 위 브랜드색 텍스트·아이콘 (iOS `indigo400`) |
| | `brandPrimarySoft` | `#99ABFF` | pending 링·저강조 (iOS `indigo300`) |
| | `brandAccent` | `#FF731A` | **The Ping 배지·브랜드 강조 전용** (iOS `orange500`) |
| 상태 | `statusActive` / `statusPending` | `#4869F0` / `#B2B8BF` | 진행 중 / 승인 대기 |
| | `statusSuccess` / `statusWarning` / `statusError` | `#30D158` / `#FFB340` / `#FF453A` | 완료 / 주의 / 실패 |
| 텍스트 | `textPrimary` / `textSecondary` / `textDisabled` | `#FFFFFF` / `#B2B8BF` / grey 50% | 본문 / 보조 / 비활성 라벨 |

- `brandAccent` 는 상태(성공/경고/실패) 표현에 **절대 쓰지 않는다** — 상태는 `status*` 축 (`WatchColor.swift:39-41`).
- `statusActive` 는 `brandPrimary` 와 같은 값이지만 의미가 다르므로 별도 이름으로 참조한다 (`WatchColor.swift:45-46`).
- 색 이름은 역할 기반이다 — iOS 팔레트 번호(`indigo500`)를 워치 API 에 노출하지 않는다 (절대 규칙 #7).

### 2-2) iOS 와의 정합은 테스트가 잠근다

iOS 와 값을 공유하는 것은 **브랜드 4종 + 중립 회색 1종**뿐이고, 그 정합은 `WatchColorTokenTests` 가 강제한다. 이 모듈은 asset 을 링크하지 않으므로 테스트가 `#filePath` 로 소스 트리를 역산해 (`Tests/WatchColorTokenTests.swift:84-88`) iOS `Core/DesignSystem/Resources/Colors.xcassets` 의 colorset `Contents.json` 을 직접 파싱하고, `appearances` 키가 없는 universal 엔트리의 RGB 를 워치 리터럴과 비교한다 (`Tests/WatchColorTokenTests.swift:31-62`).

| 워치 토큰 | iOS colorset (universal) |
|-----------|--------------------------|
| `brandPrimary` | `Primary/indigo500` |
| `brandPrimaryHighlight` | `Primary/indigo400` |
| `brandPrimarySoft` | `Primary/indigo300` |
| `brandAccent` | `Accent/orange500` |
| `neutralGrey` (→ `textSecondary`·`statusPending`) | `Grey/grey400` |

iOS 쪽에서 브랜드 색을 바꾸면 이 테스트가 즉시 깨진다 → 워치 리터럴도 같이 갱신하게 강제된다.

### 2-3) 시맨틱 상태색 3종은 iOS 와 **의도적으로 다르다**

드리프트가 아니라 결정이다 — 워치는 항상 검정 배경이라 Apple 다크 시스템 팔레트가 대비를 낸다 (`WatchColor.swift:10-11`, `Tests/WatchColorTokenTests.swift:5-7`). 그래서 테스트로 잠그지 않는다.

| 상태 | 워치 (Apple 다크 팔레트) | iOS DS |
|------|--------------------------|--------|
| success | `#30D158` | `#33A881` |
| warning | `#FFB340` | `#FFA500` |
| error | `#FF453A` | `#DD4646` |

## 3) 타이포 (`Font.watch`) · 레이아웃 (`WatchLayout`)

### 3-1) 타이포 — 5단계, 전부 `Font.TextStyle` 기반

`.font(.watch(.screenTitle))` 형태로 쓴다 (`WatchTypography.swift:30-43`). 고정 pt(`Font.system(size:)`)를 쓰지 않는 이유: Dynamic Type 에 반응하지 않는다. 괄호 안 pt 는 기본 크기에서의 실현값이다.

| Role | 매핑 | 용도 |
|------|------|------|
| `.screenTitle` | `.title2` semibold (≈22pt) | 화면 타이틀 |
| `.metric` | `.largeTitle` rounded semibold + `monospacedDigit()` (≈34pt) | 대형 지표 (카운트다운·인원수) |
| `.cardLabel` | `.caption` medium (≈13pt) | 카드 라벨 |
| `.cardValue` | `.body` regular (≈16pt) | 카드 값 |
| `.caption` | `.caption2` regular (≈12pt) | 캡션·보조 설명 |

- 버튼 라벨은 이 스케일에 없다 — watchOS 버튼 스타일의 기본 폰트를 존중한다 (`WatchTypography.swift:8`).
- `.extraLargeTitle` 은 watchOS unavailable → `metric` 이 `.largeTitle` 을 쓴다 (§8-2).

### 3-2) 레이아웃 — iOS `DefaultConstant` 를 재사용하지 않는다

iOS 상수는 탭바·44pt 터치 타깃 등 폰 전제 값이다 (`WatchLayout.swift:3-4`).

| 상수 | 값 | 용도 |
|------|----|------|
| `cardCornerRadius` | `Edge.Corner.Style` 22 | 카드/행 모서리 — `ConcentricRectangle` 의 `minimum` |
| `cardBorderWidth` | 1 | 카드 보더 |
| `cardContentPadding` | 12 | 카드 내부 패딩 (iOS 16~24 보다 타이트) |
| `screenHorizontalPadding` | 4 | 화면 좌우 인셋 — 디스플레이 곡률에 안 물리는 최소값 |
| `stackSpacing` | 8 | 카드/섹션 사이 세로 간격 |
| `tightSpacing` | 4 | 라벨-값처럼 붙는 요소 간격 |
| `accentBarWidth` | 3 | 긴급 표시 좌측 색바 (#1208) |
| `cardShape` (computed) | `ConcentricRectangle` | 카드와 동일 곡률. 중첩 콘텐츠 clip·히트영역 정합용 (`WatchSurface.swift:55-59`) |

## 4) Glass 허용/금지 매트릭스

이 문서의 핵심. 워치에서 Glass 는 **컨트롤(버튼)에만** 허용된다. 근거는 가독성(콘텐츠 배경 대비 붕괴)·배터리(OLED 순수 블랙 유지)·번인이다.

| 대상 | Glass | 실제 처리 | 근거 |
|------|:-----:|-----------|------|
| 화면 전체 배경 | ❌ | `watchScreenBackground()` → `containerBackground(WatchColor.screen, for: .navigation)` | OLED 순수 블랙 (배터리·번인) |
| 일반/Hero/위험 카드 배경 | ❌ | `watchCard(_:)` — 불투명 solid + 1pt 보더 | 가독성. 콘텐츠 배경 Glass 금지 |
| `List`·`Table` 행 배경 | ❌ | `watchListRowBackground(isSelected:)` — solid 표면 | 금지 구역 (#1208) |
| 선택된 `List` 행 | ❌ | Hero 표면 + 좌측 색바 (§5-3) | solid tint (#1207) |
| 결과 풀스크린 배경 (#1207) | ❌ | `watchScreenBackground()` + `watchCard(.hero/.danger)` | 금지 구역 |
| Complication (#1215) | ❌ | 토큰 색만 사용 — accessory family 는 시스템이 렌더 | 금지 구역 |
| Primary CTA | ✅ | `.buttonStyle(.glassProminent)` + 인디고 tint | 컨트롤 = 허용 구역 |
| Secondary 버튼 | ✅ | `.buttonStyle(.glass)` (tint 없음) | 컨트롤 |
| Destructive-safe 버튼 | ✅ | `.buttonStyle(.glass)` + 에러 레드 tint (채우지 않음) | 컨트롤 |
| Disabled 버튼 | ✅(무tint) | `.buttonStyle(.glass)` + `textDisabled` + `.disabled(true)` | 컨트롤 |
| 상태 배지 | ❌ | 심볼 + 텍스트, 배경 없음 | — |

### 4-1) 금지 규칙이 API 수준에서 강제되는 방식

1. **모듈이 `glassEffect` 래퍼를 하나도 노출하지 않는다.** `import CoreWatchDesignSystem` 만으로는 배경에 Glass 를 얹을 방법이 없다. SwiftUI 를 직접 불러 쓰는 건 명시적 이탈이라 PR 리뷰에서 잡는다.
2. **`WatchCardStyle` 은 solid 3케이스 닫힌 enum** (`WatchSurface.swift:5-14`) — Glass 배리언트가 존재하지 않는다.
3. **배경 토큰은 `Color` 타입이지 `Material` 이 아니다** — `WatchColor.cardBackground` 로는 반투명을 만들 수 없다.
4. **Glass API 는 `WatchActionButton` 내부에서만 등장한다.** grep 으로 검증한다:

```bash
grep -rn "glassEffect\|buttonStyle(.glass" UMCApp/Core/WatchDesignSystem/Sources
# → WatchActionButton.swift 한 파일만 나와야 한다 (현재 76·83·85·87행).
#   WatchSurface.swift / WatchColor.swift 에서 매치가 나오면 금지 구역 위반.
```

## 5) 표면 API — 카드·화면 배경·리스트 행

### 5-1) `watchCard(_:leadingAccent:)`

패딩·불투명 배경·1pt 보더·동심 모서리를 한 번에 적용한다 (`WatchSurface.swift:91-115`).

```swift
VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
    Text("다음 출석")
        .font(.watch(.cardLabel))
        .foregroundStyle(WatchColor.textSecondary)
    Text("12:30")
        .font(.watch(.metric))
        .foregroundStyle(WatchColor.textPrimary)
}
.watchCard(.hero)

// 긴급 공지 (#1208) — 색과 분리된 위치 신호
NoticeRow(notice: notice)
    .watchCard(leadingAccent: WatchColor.brandAccent)
```

| `WatchCardStyle` | fill / border | 용도 |
|------------------|---------------|------|
| `.standard` (기본) | `#16181C` / `#2A2D34` | 일반 카드 |
| `.hero` | `#1B2140` / 인디고 45% | 대표 지표·다음 일정 |
| `.danger` | `#241416` / 에러 레드 40% | 위험·실패·파괴적 맥락 |

구현 결정 두 가지 (`WatchSurface.swift:95-102`):

- `ConcentricRectangle` 은 `InsettableShape` 가 아니라 `strokeBorder` 를 못 쓴다 → 보더는 `clipShape` **뒤에** `stroke` + `overlay` 로 얹어 1pt 를 온전히 남긴다.
- `containerShape` 는 붙이지 않는다 — §8-1 의 컴파일 제약 때문. 중첩 콘텐츠는 `WatchLayout.cardShape` 로 직접 맞춘다.

### 5-2) `watchScreenBackground()`

화면 전체를 순수 블랙으로 고정하고 watchOS 기본 네비게이션 그라디언트를 덮는다 (`WatchSurface.swift:117-123`). **`NavigationStack` destination 의 최상위 콘텐츠**에 적용한다.

```swift
ScrollView { /* … */ }
    .watchScreenBackground()
```

### 5-3) `watchListRowBackground(isSelected:)`

기본 시스템 행 배경(반투명)을 불투명 solid 로 교체한다 (`WatchSurface.swift:125-142`). `isSelected: true` 면 Hero 표면 + **좌측 인디고 색바**로 선택을 표현한다 — Hero fill 단독은 standard 대비 명암비 1.13:1 에 그쳐 저시력·야외에서 식별되지 않으므로, 색과 분리된 위치 신호를 함께 준다 (#1207 선택행).

```swift
List(schedules) { schedule in
    ScheduleRow(schedule: schedule)
        .watchListRowBackground(isSelected: schedule.id == selectedID)
}
```

## 6) 컴포넌트

### 6-1) `WatchActionButton`

워치 공통 CTA (`WatchActionButton.swift:40-52`). 캡슐 형태·높이는 시스템 기본값을 존중한다 — iOS `PrimaryButtonStyle` 의 `height: 44` 를 가져오면 큰 Dynamic Type 에서 라벨이 잘린다.

```swift
public init(
    _ title: String,
    role: WatchButtonRole = .secondary,    // .primary | .secondary | .destructive
    systemImage: String? = nil,
    disabledReason: String? = nil,
    action: @escaping () -> Void
)
```

| `WatchButtonRole` | 스타일 | 규칙 |
|-------------------|--------|------|
| `.primary` | `.glassProminent` + 인디고 tint | 화면당 1개 — 기본값이 아니라 대표 CTA 에만 명시 |
| `.secondary` | `.glass` 중립 | 보조 액션 |
| `.destructive` | `.glass` + 에러 레드 tint | **채우지 않는** 안전형 — 빨간 채움 버튼은 좁은 화면에서 오탭 유도 |

```swift
// #1207 하단 고정 CTA
List { /* … */ }
    .watchScreenBackground()
    .safeAreaInset(edge: .bottom) {
        WatchActionButton("출석 체크", systemImage: "checkmark") {
            viewModel.checkIn()
        }
    }

// 비활성 + 사유 — disabledReason 이 유일한 비활성 경로다
WatchActionButton(
    "출석 체크",
    disabledReason: viewModel.isOutOfRange ? "출석 장소에서 200m 밖입니다" : nil,
    action: viewModel.checkIn
)
```

`disabledReason` 이 있으면 역할과 무관하게 회색조 `.glass` + `.disabled(true)` 로 바뀌고, 사유가 버튼 아래 캡션으로 노출되며 VoiceOver 에는 `accessibilityValue` 로 전달된다 (`WatchActionButton.swift:74-79`). **사유 없는 비활성 버튼은 만들 수 없다.**

### 6-2) `WatchStatusBadge` / `WatchStatus`

상태 표시. 색 단독으로 상태를 표현하지 않는다 — 5종 심볼의 **실루엣이 서로 다르고**(`WatchStatus.symbolName`, `WatchStatusBadge.swift:40-48`), 기본적으로 텍스트를 병기한다.

| `WatchStatus` | 심볼 (실루엣) | tint | `defaultLabel` |
|---------------|----------------|------|-----------------|
| `.active` | `circle.fill` (원판) | `statusActive` | 진행 중 |
| `.pending` | `smallcircle.filled.circle` (점+링) | `statusPending` / 링 `brandPrimarySoft` | 승인 대기 |
| `.success` | `checkmark.circle.fill` (원안 체크) | `statusSuccess` | 완료 |
| `.warning` | `exclamationmark.triangle.fill` (삼각형) | `statusWarning` | 주의 |
| `.error` | `xmark.octagon.fill` (팔각형) | `statusError` | 실패 |

- `pending` 링이 `brandPrimary` 가 아니라 한 단계 밝은 `brandPrimarySoft` 인 이유: `active` 원판과 같은 인디고를 쓰면 라벨 없는 경로에서 둘이 섞인다 (`WatchStatusBadge.swift:31-35`).
- 심볼 오타·SF Symbols 버전 변경은 `WatchStatusSymbolTests` 가 잡는다 (`Tests/WatchColorTokenTests.swift:139-145`).

```swift
// 홈 글랜스 (#1206) — 텍스트 병기 (기본)
WatchStatusBadge(.pending, label: "승인 대기 3건")

// 목록 행 (#1208) — 폭이 없어 심볼만, 접근성 라벨로 의미 유지
WatchStatusBadge(.warning, label: "마감 임박", showsLabel: false)
```

## 7) 접근성 계약

| 요구 | 처리 |
|------|------|
| 상태를 색 단독으로 표현 금지 | `WatchStatus` 5종의 심볼 실루엣이 전부 다르다 (원판/점+링/원안 체크/삼각형/팔각형) + `defaultLabel` 이 항상 존재해 문구 누락 불가 |
| 배지 낭독 1회 | `showsLabel: true` — 심볼 `accessibilityHidden(true)` + 전체 `.accessibilityElement(children: .combine)` → 텍스트만 한 번 낭독 (`WatchStatusBadge.swift:96-103`) |
| 심볼 단독 사용 | `showsLabel: false` 경로는 심볼을 숨기지 않고 `.accessibilityLabel(resolvedLabel)` 을 붙인다 — 숨기면 정보가 사라진다 (`WatchStatusBadge.swift:105`) |
| 비활성 사유 | `disabledReason` 이 유일한 비활성 경로. VoiceOver 에는 `accessibilityValue` — hint 는 VoiceOver 설정에서 꺼질 수 있는 보조 정보인데 "왜 못 누르는가"는 필수 정보다 (`WatchActionButton.swift:22-24`). 캡션은 `accessibilityHidden(true)` 로 중복 낭독 차단 |
| Dynamic Type | 타이포 전부 `Font.TextStyle` 기반, **고정 pt·고정 높이가 하나도 없다.** 심볼도 `.font(.watch(.cardLabel))` 로 텍스트와 함께 스케일 (`WatchStatusBadge.swift:111-116`) |

## 8) 알려진 제약 2건

후속 이슈(#1206~#1209·#1215)가 반드시 알아야 하는 제약이다.

### 8-1) `containerShape` 로 동심 곡률을 전달할 수 없다

`ConcentricRectangle` 이 `RoundedRectangularShape` 를 채택하지 않아 `.containerShape(.rect(corners: .concentric(minimum:)))` 가 **컴파일되지 않는다**. 리터럴 반경(22)을 `containerShape` 로 선언하는 우회도 틀렸다 — 실제 해석값(디스플레이 곡률 기반, 22 초과)과 달라 자식이 틀린 값을 상속한다 (`WatchSurface.swift:99-102`).

→ 카드 안 중첩 콘텐츠의 clip·히트영역은 `WatchLayout.cardShape` 로 직접 맞춘다:

```swift
Image(uiImage: thumbnail)
    .clipShape(WatchLayout.cardShape)
```

> ⚠️ `docs/claude/design-system.md:56` 이 바로 이 컴파일 불가 패턴(`containerShape(.rect(corners: .concentric(...)))`)을 iOS 프로젝트 규약으로 문서화해 두고 있다. 레포 내 실제 사용처가 0건이라 아무도 밟지 않았을 뿐이다. **그 문서는 이번 작업(#1205)에서 고치지 않았다** — iOS 쪽 수정 시 별도 확인이 필요하다.

### 8-2) `Font.TextStyle.extraLargeTitle` 은 watchOS unavailable

visionOS 전용이다. 대형 지표는 `.largeTitle` 을 쓴다 — `WatchTextRole.metric` 이 이미 그렇게 매핑돼 있으므로 (`WatchTypography.swift:29-35`) 화면 코드에서 텍스트 스타일을 직접 고르지 말고 `.font(.watch(.metric))` 을 쓰면 된다.

## 9) 폴백(에러·오프라인) 계약

#1209 가 구현한 P0 실패·오프라인 처리 8종 화면의 계약. 화면 목록보다 **왜 무음 실패가 구조적으로 불가능한지**, **표시 형태가 왜 3가지로 갈리는지**에 초점을 둔다. 기준 코드는 `UMCApp/UMCWatchApp/Sources/Fallback/` 전체와 `Sources/Routing/WatchRoute.swift`·`WatchRootView.swift`.

### 9-1) 실패 원인 4축과 9개 `WatchFallbackReason`

`WatchFailureCategory`(`WatchFallbackReason.swift:9-18`)는 화면을 고르는 축이 아니라 **원인을 진단하는 축**이다 — 같은 축이어도 사용자가 할 수 있는 행동이 다르면 화면은 갈라진다(`WatchFallbackReason.swift:7-8`).

| P0 | `WatchFallbackReason` | `WatchFailureCategory` | 설명 |
|----|------------------------|-------------------------|------|
| P0-1 | `.locationPermissionDenied` | `.permission` | 위치 권한 거부 |
| P0-2 | `.locationUnavailable` | `.connectivity` | 위치 확인 실패(GPS 타임아웃 등) |
| P0-3 | `.phoneDisconnected` | `.connectivity` | iPhone 연결 끊김 |
| P0-4 | `.checkInRequestFailed` | `.server` | 출석 요청 실패 |
| P0-5 | `.alreadyCheckedIn` | `.session` | 이미 출석 처리됨 |
| P0-6 | `.checkInWindowClosed` | `.session` | 출석 인정 시간 마감 |
| P0-7 | `.offlineQueued` | `.connectivity` | 전송 대기 중(유효 시간 이내) |
| P0-7 | `.offlineQueueExpired` | `.connectivity` | 전송 유효 시간 초과 |
| P0-8 | `.mandatoryNoticeUnread` | `.session` | 필수 확인 공지 미확인 |

화면은 8종인데 `WatchFallbackReason` 은 9개인 이유: P0-7 대기/만료는 스펙상 "한 프레임 두 상태"라 컴포넌트(`WatchOfflineQueueCard`)는 하나지만, `reason` 은 둘로 갈라져 문구·아이콘·CTA 를 통째로 바꿔 낀다(`WatchOfflineQueue.swift:38-39`, §9-5).

### 9-2) 무음 실패 금지 3중 잠금

`WatchFallbackReason` 은 연관값 없는 enum 이다. 이 설계 자체가 세 겹의 안전장치를 건다.

**(a) `CaseIterable` 이 공짜로 합성된다.** 연관값이 없는 enum 은 Swift 가 `allCases` 를 자동으로 만들어 준다(`WatchFallbackReason.swift:24-30`). 새 케이스를 추가하면 `WatchFallbackReasonTests` 가 별도 등록 없이 그 케이스를 바로 검사한다 — 제목·설명이 비어있지 않은지(`Tests/WatchFallbackReasonTests.swift:12-18`), 4축이 전부 커버되는지(`:26-30`), 비활성 CTA 는 반드시 사유를 가지는지(`:101-107`). `WatchFallbackScene` 의 "9종 갤러리" 프리뷰도 같은 `allCases` 를 돈다(`WatchFallbackScene.swift:90`).

**(b) `category`·`presentation` 스위치에 `default:` 가 없다.** 케이스를 추가하면 두 스위치(`WatchFallbackReason.swift:52-68`, `WatchFallbackPresentation.swift:74-197`) 모두 분기 누락으로 **컴파일 에러**가 난다 — 새 실패 원인이 분류·문구 없이 조용히 묻히는 경로 자체가 없다.

**(c) `init(classifying:)` 이 Optional 이 아니다.** 어떤 `Error` 를 넣어도 반드시 `WatchFallbackReason` 하나가 나온다(`WatchFallbackReason.swift:78-101`). 분류할 수 없는 에러는 `.checkInRequestFailed` 로 보낸다 — 재시도와 iPhone 대체 경로를 모두 가진 유일한 복구 가능 화면이라, 원인을 몰라도 사용자가 막히지 않는다(`:98-99`).

### 9-3) 동작 없는 CTA 금지 규약

`WatchFallbackScene.onPrimaryAction`/`onSecondaryAction` 은 옵셔널 클로저다(`WatchFallbackScene.swift:14-17`).

```swift
var onPrimaryAction: (() -> Void)?
var onSecondaryAction: (() -> Void)?
```

핸들러를 안 넘기면 해당 CTA 는 **아예 렌더되지 않는다** — 눌러도 아무 일도 없는 버튼이 곧 무음 실패이기 때문이다(`WatchFallbackScene.swift:66-82`). `disabledAction` 이 있으면 그것만 그리고 primary/secondary 는 무시한다 — 비활성인 이상 활성 CTA 와 공존할 이유가 없다(`:59-64`).

`WatchActionButton(disabledReason:)` 의 "사유 없는 비활성 버튼은 만들 수 없다" 규약(§6-1)과 같은 계열이다. 둘 다 값 레벨(옵셔널 `nil`)로 "동작 없는 버튼"을 애초에 만들 수 없게 막는다 — `disabledActionsAlwaysCarryAReason` 테스트(`Tests/WatchFallbackReasonTests.swift:101-107`)가 이 계약을 검사한다.

### 9-4) 표시 형태 3종

같은 `WatchFallbackScene`(심볼+제목+설명+힌트+CTA)을 배경만 바꿔 세 곳에 재사용한다(`WatchFallbackScene.swift:6-8`).

| 형태 | 컴포넌트 | 배경 | 쓰임 |
|------|----------|------|------|
| 전체화면 | `WatchFallbackView` | `watchScreenBackground()` | `WatchRoute.fallback(reason)` 라우팅 목적지(`WatchRoute.swift:23-25`, `WatchFallbackView.swift:10-34`) |
| 인라인 카드 | `WatchOfflineQueueCard` | `watchCard(.standard/.danger)` | 화면 안에 직접 박히는 P0-7(`WatchOfflineQueue.swift:40-52`) |
| 상단 고정 배너 | `WatchMandatoryNoticeBanner` | `watchCard(leadingAccent:)` | P0-8, `WatchRootView` 최상위(`WatchMandatoryNotice.swift:40-56`) |

배너가 `NavigationStack` **바깥** `safeAreaInset(edge: .top)` 에 붙는 이유(`WatchRootView.swift:25-31`): 스택 **안**에 두면 좌측 엣지 스와이프가 pop 으로 소비돼 "확인 전까지 무시 불가" 계약이 깨진다(`WatchMandatoryNotice.swift:38-39`). `WatchMandatoryNoticeCenter.confirm()` 을 사용자가 직접 호출하는 경로만 배너를 닫는다 — 스와이프·무시 경로는 없다(`WatchMandatoryNotice.swift:30-33`).

### 9-5) 오프라인 큐 3시간 유효창

서버는 수신 시각 기준 **과거 180분(3시간) 이내**만 출석 판정에 쓴다(`WatchOfflineQueue.swift:7-8`). 워치는 같은 값을 `WatchOfflineQueueWindow.validity`(`WatchOfflineQueue.swift:12`)로 들고 있다가, 측정 시각으로부터 3시간이 지난 항목은 **보내기 전에 스스로 버린다** — 서버가 어차피 거부할 요청을 굳이 네트워크로 왕복시키지 않는다.

```swift
static let validity: TimeInterval = 3 * 60 * 60

static func state(measuredAt: Date, now: Date) -> WatchOfflineQueueState {
    let elapsed = now.timeIntervalSince(measuredAt)
    let remaining = validity - max(elapsed, 0)
    guard remaining > 0 else { return .expired }
    return .waiting(remaining: remaining)
}
```

`state(measuredAt:now:)` 는 `Date.now` 를 직접 읽지 않는 순수 함수다(`WatchOfflineQueue.swift:14`) — 임의 시각을 주입해 경계값을 검증할 수 있다. 대기 중에는 "남은 유효 시간 N시간 M분"을 `replacingHint(_:)` 로 꽂고(`WatchOfflineQueue.swift:60-67, 69-74`), 만료되면 `.offlineQueueExpired` 화면으로 전환해 공결 사유 제출(iPhone)로 안내한다(`WatchFallbackPresentation.swift:172-182`).

### 9-6) 아이콘 대체 기록

스펙의 "bt-slash" 에 대응하는 Bluetooth 글리프가 SF Symbols 에 없어 `iphone.slash` 를 쓴다(`WatchFallbackPresentation.swift:100-103`). 대체 근거는 디자인 절충이 아니라 **문구 정합**이다 — 화면 문구가 "iPhone 과 연결이 끊겼습니다"라 `iphone.slash` 가 오히려 더 정확하다.

## 10) 체크리스트 — 워치 화면을 올릴 때

- [ ] `NavigationStack` destination 최상위 콘텐츠에 `watchScreenBackground()` 적용
- [ ] 좌우 인셋은 `WatchLayout.screenHorizontalPadding`, 세로 간격은 `stackSpacing`/`tightSpacing`
- [ ] 카드·행·풀스크린 배경에 Glass·`Material`·`glassEffect` 미사용 — §4-1 의 grep 으로 확인
- [ ] 텍스트는 전부 `.font(.watch(...))` — `Font.system(size:)` 고정 pt 금지
- [ ] 상태 표현은 `WatchStatus`/`WatchStatusBadge` — `brandAccent` 로 상태를 그리지 않기
- [ ] 비활성 버튼은 `disabledReason` 으로만 — `.disabled(true)` 직접 호출 금지
- [ ] 카드 내 중첩 clip 은 `WatchLayout.cardShape` (§8-1)
- [ ] iOS 브랜드 팔레트를 건드렸다면 `make test SCHEME=CoreWatchDesignSystem` 으로 드리프트 확인
- [ ] 프리뷰를 46mm·40mm 와 `.dynamicTypeSize(.accessibility3)` 에서 확인 (갤러리: 각 컴포넌트 파일의 `#Preview`)
- [ ] 새 실패 원인은 `WatchFallbackReason` 케이스로 추가하고 `category`/`presentation` 스위치를 전부 채운다 — `default:` 없이 컴파일 에러로 강제된다 (§9-2)
- [ ] 폴백 CTA 는 `onPrimaryAction`/`onSecondaryAction` 핸들러를 실제로 넘겼는지 확인 — 안 넘기면 버튼이 그려지지 않는다 (§9-3)

## 11) 트러블슈팅

- 증상: `WatchColorTokenTests` 실패 — "브랜드 토큰 드리프트 — WatchColorHex.… ≠ ….colorset universal"
  - 원인: iOS `Colors.xcassets` 의 브랜드/회색 팔레트가 바뀌었는데 워치 리터럴이 안 따라갔다 (`Tests/WatchColorTokenTests.swift:13-25`).
  - 해결: `WatchColorHex` 의 해당 리터럴을 iOS universal 값과 같게 갱신한다. success/warning/error 는 대상이 아니다 — 의도적으로 다르다 (§2-3).
- 증상: 테스트가 "colorset 을 읽지 못했다" / "universal 엔트리를 찾지 못했다" / "0xRR 형식이 아니다" 로 실패
  - 원인: `Colors.xcassets` 경로 이동 또는 `Contents.json` 포맷 변경. 파싱 실패는 조용히 통과하지 않도록 `Issue.record` 로 명시적으로 실패한다 (`Tests/WatchColorTokenTests.swift:31-75`).
  - 해결: `colorsAssetRoot` 경로 역산(`Tests/WatchColorTokenTests.swift:84-88`) 또는 채널 파서를 새 구조에 맞춘다.
- 증상: `.containerShape(.rect(corners: .concentric(...)))` 가 컴파일 에러
  - 원인: §8-1 — `ConcentricRectangle` 이 `RoundedRectangularShape` 비채택.
  - 해결: 중첩 콘텐츠에 `WatchLayout.cardShape` 를 직접 쓴다.
- 증상: `.extraLargeTitle` 사용 시 watchOS 타겟에서 unavailable 컴파일 에러
  - 원인: §8-2 — visionOS 전용 케이스.
  - 해결: `.font(.watch(.metric))` 사용.
- 증상: 워치에서 브랜드 인디고가 `#4264F0` 등 어두운 값으로 보인다
  - 원인: iOS `Colors.xcassets` 를 워치 타겟에 링크했다 — watchOS 는 dark 엔트리를 집는다 (§1).
  - 해결: 워치 코드는 `WatchColor` 만 쓴다. iOS 카탈로그를 워치 타겟에 링크하지 않는다.
- 증상: pending 배지가 회색 점 + 인디고 링이 아니라 뒤집혀/단색으로 보인다
  - 원인: 팔레트 렌더링 레이어 순서 — `foregroundStyle(status.tint, status.ringTint)` 의 인자 순서가 레이어 0(점)·레이어 1(링)에 대응한다 (`WatchStatusBadge.swift:111-116`).
  - 해결: 인자 순서를 유지하고, SF Symbols 버전 변경이 의심되면 `WatchStatusSymbolTests` 를 돌려 심볼 존재부터 확인한다.
- 증상: 새 `WatchFallbackReason` 케이스를 추가했더니 빌드가 깨진다
  - 원인: `category`(`WatchFallbackReason.swift:52-68`)와 `presentation`(`WatchFallbackPresentation.swift:74-197`) 스위치에 `default:` 가 없다 — 의도된 설계다 (§9-2).
  - 해결: 두 스위치 모두에 새 케이스 분기를 채운다.
- 증상: 폴백 화면에서 "다시 시도"/"iPhone 에서 시도" 버튼이 하나도 안 보인다
  - 원인: `WatchFallbackScene.onPrimaryAction`/`onSecondaryAction` 핸들러를 호출부에서 안 넘겼다 — nil 이면 해당 CTA 자체를 그리지 않는다 (`WatchFallbackScene.swift:14-17, 66-82`).
  - 해결: 핸들러를 전달하거나, 애초에 눌러도 할 일이 없다면 `presentation.primaryAction`/`secondaryAction` 을 `nil` 로 둔다.
- 증상: 필수 확인 배너가 화면 전환 중 스와이프로 사라진다
  - 원인: `WatchMandatoryNoticeBanner` 를 `NavigationStack` 안에 배치했다 — 좌측 엣지 스와이프가 pop 으로 소비된다 (§9-4).
  - 해결: `WatchRootView` 최상위 `safeAreaInset(edge: .top)` 에서만 렌더한다 (`WatchRootView.swift:25-31`).
- 증상: 오프라인 큐 카드가 3시간이 지나도 계속 "전송 대기 중"으로 보인다
  - 원인: `measuredAt`/`now` 를 갱신하지 않아 `WatchOfflineQueueWindow.state(measuredAt:now:)` 가 매번 같은 경과 시간을 계산한다 (`WatchOfflineQueue.swift:15-22`).
  - 해결: 카드에 실제 현재 시각을 흘려보내 만료 판정을 다시 계산하게 한다.
