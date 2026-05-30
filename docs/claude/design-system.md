# 디자인 시스템 + 성능 최적화

> 디자인 토큰, Typography, Glass Effect, 공용 컴포넌트, 렌더링 최적화 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고. iOS 26 프레임워크 API 상세는 `docs/claude/ios26-frameworks/` 참고.

토큰 정의: `DefaultConstant.swift`, `DefaultSpacing.swift`

## 레이아웃 상수 (`DefaultConstant`)

| 상수 | 값 | 용도 |
|------|----|------|
| `defaultSafeHorizon` | 16 | 좌우 기본 여백 |
| `defaultSafeTop` | 20 | 상단 기본 여백 |
| `defaultSafeBottom` | 56 | 하단 탭바 safe area |
| `defaultCornerRadius` | 30 | 기본 모서리 반경 |
| `concentricRadius` | 40 | ConcentricRectangle 최소 반경 |
| `defaultCapsuleSpacing` | 28 | 캡슐형 요소 여백 |

## Typography (`AppFont`)

Pretendard 기반. `.appFont()` modifier로 줄간격 포함, `.font(.app())` 으로 줄간격 제외.

| Scale | Size | 용도 |
|-------|------|------|
| `.largeTitle` | 34pt | 최상위 제목 |
| `.title1` | 28pt | 주요 제목 |
| `.title2` | 22pt | 섹션 제목 |
| `.title3` | 20pt | 서브 섹션 |
| `.headline` | 17pt | 강조 본문 |
| `.callout` | 16pt | 카드 제목 |
| `.subheadline` | 15pt | 부제목 |
| `.footnote` | 13pt | 부가정보 |
| `.caption1` | 12pt | 보조 레이블 |
| `.caption2` | 11pt | 최소 텍스트 |

`Emphasis` 변형(예: `.calloutEmphasis`)은 자동으로 Bold weight 적용.

### Typography 계층 (용도별)

| 용도 | AppFont | Color |
|------|---------|-------|
| 제목 | `.calloutEmphasis` | 기본 |
| 부제목 | `.subheadline` | `.grey600` |
| 부가정보 | `.footnote` | `.grey500` |

## Shape 패턴 (권장)

```swift
// ConcentricRectangle 사용 (디바이스별 일관성)
.clipShape(
    ConcentricRectangle(
        corners: .concentric(minimum: DefaultConstant.concentricRadius),
        isUniform: true
    )
)
.containerShape(.rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
```

## Glass Effect 선택

| Variant | 용도 |
|---------|------|
| `.regular` | 일반 카드, 폼 |
| `.regular.interactive()` | 탭 가능 요소 |
| `.clear` | 미디어/색상 배경 위 |
| `.glassProminent` (ButtonStyle) | Primary 버튼 |
| `.glass` (ButtonStyle) | Secondary 버튼 |

> Liquid Glass API 전체 사용법은 `docs/claude/ios26-frameworks/SwiftUI-Implementing-Liquid-Glass-Design.md` 참고.

## 공용 UI 컴포넌트 (`Core/Common/UIComponents/`)

| 컴포넌트 | 설명 |
|---------|------|
| `ArticleTextField` | 제목/본문 겸용 텍스트 입력 (`.title`, `.content` 타입) |
| `Badge` | 상태 뱃지 |
| `ChipButton` | 칩 형태 버튼 |
| `Icon` | 아이콘 래퍼 |
| `Loading` | 로딩 인디케이터 |
| `Logo` | 앱 로고 |
| `MainButton` | 주요 CTA 버튼 |
| `PlaceSelectView` | 장소 선택 뷰 |
| `Progress` | 진행률 표시 |
| `Section` | 섹션 컨테이너 |
| `SectionErrorCard` | 섹션 에러 표시 카드 |
| `State` | 빈 상태/에러 상태 뷰 |

```swift
// ArticleTextField 사용 예시
ArticleTextField(
    placeholder: .title,
    text: $text,
    focused: $focused,
    submitLabel: .return,
    onSubmit: { /* action */ }
)
```

## 성능 최적화

### Liquid Glass (iOS 26)

- `GlassEffectContainer`로 그룹화 필수 (오프스크린 렌더링 66% 감소)
- `glassEffectID`는 모핑 애니메이션 필요 시만 사용 (CPU 부하)
- 적용 불가: List, Table, 미디어 콘텐츠

### View 렌더링

- Container-Presenter 패턴: Container(상태/로직) + Presenter(UI + Equatable)
- 클로저는 Equatable 비교에서 제외

```swift
struct CardPresenter: View, Equatable {
    let id: UUID
    let name: String
    var onTap: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
```

### List/ForEach

- List 우선 사용 (LazyVStack보다 뷰 재사용 효율적)
- ForEach 내 조건부 뷰 금지 (lazy loading 깨짐)
- List에서 `.id()` 모디파이어 사용 금지
