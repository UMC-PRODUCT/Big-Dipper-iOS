# Notice Editor RichText & AI Guide

공지 작성 화면(`NoticeEditorView`)의 두 축인 **리치 텍스트 / 마크다운 파이프라인**과 **Apple Intelligence(FoundationModels) 기반 본문 개선 기능**을 한 문서에 정리합니다. 두 기능은 동일한 `NoticeEditorViewModel`을 공유하며, AI 결과물이 다시 마크다운 파이프라인으로 흘러 들어가 왕복(round-trip)을 이룹니다.

- 작성자: euijjang97
- 기준 코드:
  - `AppProduct/AppProduct/Features/Notice/Presentation/Views/NoticeEditor/RichTextEditor/NoticeRichTextView.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownSerializer.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/Views/NoticeEditor/RichTextEditor/Serializer/MarkdownSerializerTypes.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/ViewModels/NoticeEditor/EditorToolbar/EditorToolbarViewModel.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/ViewModels/NoticeEditor/EditorToolbar/EditorToolbarTypes.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/ViewModels/NoticeEditor/NoticeEditorViewModel+AI.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/Views/NoticeEditor/Overlay/AIConfirmationOverlay.swift`
  - `AppProduct/AppProduct/Features/Notice/Presentation/Views/NoticeEditor/Overlay/AILoadingOverlay.swift`
  - `AppProduct/AppProduct/Features/Notice/Data/AITokenDailyUsageRecord.swift`

---

## 1) 데이터 흐름 한눈에 보기

```
┌──────────────────────────┐     ┌───────────────────────────┐
│  서버 마크다운 원문         │ ──▶ │ MarkdownSerializer         │
│  (기존 공지 수정 진입 시)   │     │   .deserialize(_:baseFont:) │
└──────────────────────────┘     └──────────────┬────────────┘
                                                │ NSAttributedString
                                                ▼
                    ┌──────────────────────────────────────────┐
                    │ NoticeRichTextView (UITextView 래퍼)       │
                    │  + EditorToolbarViewModel (@Observable)    │
                    └──────────────────────────────────────────┘
                                                │ NSAttributedString
                                                ▼
                    ┌──────────────────────────────────────────┐
                    │ MarkdownSerializer.serialize(_:)          │
                    └──────────────────────────────────────────┘
                                                │ String (markdown)
                                                ▼
                    ┌──────────────────────────────────────────┐
                    │ NoticeEditorViewModel.content (저장/전송)   │
                    └──────────────────────────────────────────┘
```

AI 개선 경로는 여기서 한 번 더 왕복합니다.

```
content (markdown)
  → plainText(trim) → SystemLanguageModel.streamResponse
  → 개선된 markdown string
  → MarkdownSerializer.deserialize → richAttributedContent (UITextView 갱신)
  → MarkdownSerializer.serialize → content
```

핵심 원칙은 **원본(serialize/deserialize 대상)은 언제나 마크다운 문자열**이라는 점입니다. 에디터 내부는 `NSAttributedString`으로 편집하지만, ViewModel의 `content` 프로퍼티와 서버 송수신 본문은 항상 마크다운입니다.

---

## 2) 마크다운 파이프라인

### 2-1) Facade: `MarkdownSerializer`

호출자(ViewModel, View)는 아래 4개의 정적 API만 사용합니다.

```swift
// 에디터 → 마크다운
MarkdownSerializer.serialize(_ attributedString: NSAttributedString) -> String

// 마크다운 → 에디터 로드용 AttributedString
MarkdownSerializer.deserialize(_ markdown: String, baseFont: UIFont) -> NSAttributedString

// 마크다운 → 상세 화면 표시용 AttributedString
MarkdownSerializer.deserializeForDisplay(_ markdown: String, baseFont: UIFont) -> NSAttributedString

// 검색 인덱싱/알림 미리보기 등 plain text 만 필요한 경로
MarkdownSerializer.plainText(from markdown: String) -> String

// 레거시 HTML 공지 감지 (edit 진입 시 파서 분기용)
MarkdownSerializer.looksLikeHTML(_ content: String) -> Bool
```

내부 구현은 SOLID 원칙에 따라 책임별로 쪼개져 있습니다.

| 파일 | 책임 |
|------|------|
| `MarkdownBlockSerializer.swift` | AttributedString → 마크다운 블록 조립 (헤딩/인용구/목록/단락) |
| `MarkdownBlockParser.swift` | 마크다운 라인 파싱 후 블록 → AttributedString 조립 |
| `MarkdownInlineSerializer.swift` | 단락 내부 인라인 서식(굵게, 이탤릭, 코드, 링크 등) 직렬화 |
| `MarkdownInlineParser.swift` | 인라인 토큰 매칭 및 재귀 파싱 |
| `MarkdownRegex.swift` | 인라인 토큰 정규식 및 **우선순위 배열** 정의 |
| `MarkdownAttributeBuilder.swift` | `MarkdownInlineStyle` → `NSAttributedString.Attributes` 변환 (Pretendard oblique 시뮬레이션 포함) |
| `MarkdownEscaping.swift` | 백슬래시 이스케이프 처리 (`\*`, `\_` 등) |
| `MarkdownHTMLDetector.swift` | HTML 휴리스틱 감지 + plain text 추출 |

Facade 계층이 존재하는 이유: **호출자는 한 타입만 바라보고, 내부 파일 구조가 바뀌어도 API 표면이 불변**입니다.

### 2-2) 지원하는 마크다운 문법

| 문법 | 적용 서식 | 비고 |
|------|----------|------|
| `# / ## / ###` | 제목 28pt / 22pt / 17pt | `EditorParagraphStyle` 과 매핑 |
| `**text**` | Bold | `.traitBold` |
| `*text*` / `_text_` | Italic | Pretendard에 italic 변형이 없어 **oblique matrix** 로 시뮬레이션 |
| `***text***` / `**_text_**` | Bold + Italic | `MarkdownInlineTokenKind.boldItalicStars` / `.boldItalicMixed` |
| `~~text~~` | Strikethrough | |
| `` `code` `` | Monospaced inline | |
| `<u>text</u>` | Underline | HTML 스타일이지만 인라인 토큰으로 처리 |
| `<mark color="R,G,B,A">text</mark>` | 배경 하이라이트 | RGBA 값을 보존하여 왕복 시 색 변형 없음 |
| `[label](url)` | 링크 | scheme 허용 목록 외는 plain text 로 유지 |
| `> text` | 블록 인용구 | `NSAttributedString.Key.editorBlockquote` 커스텀 키 |
| `- ` / `1. ` | 순서 없는/있는 목록 | `NSAttributedString.Key.editorListStyle` 로 스타일 보존 |

`MarkdownRegex.inlinePatterns` 의 **배열 순서가 우선순위**입니다. 한 구간에 여러 토큰이 매칭될 경우(예: `**_굵은 이탤릭_**`) 앞쪽 규칙이 먼저 적용됩니다. 토큰을 추가할 때는 `MarkdownInlineTokenKind` 의 case 선언 순서와 `inlinePatterns` 배열 순서를 **동일하게** 맞춰 주세요.

### 2-3) 이스케이프 처리 규칙

역직렬화 시 `\*\*not bold\*\*` 같은 입력이 실수로 굵게 렌더되지 않아야 합니다. 이를 위해 두 가지 unescape 전략을 구분합니다.

- **에디터 로드 경로**: `deserialize(_:baseFont:)` → 파서가 내부적으로 plain text 구간에서만 선택적으로 unescape. 전체 문자열을 사전 unescape **하지 않습니다**.
- **디스플레이 전처리 경로**: `unescapeForDisplay(_:)` → 단순 출력만 필요할 때 전체 문자열의 `\*`, `\_` 등을 제거. 에디터 로드에는 절대 사용하지 마세요.

잘못 사용하면 `\*not bold\*` 같은 입력이 로드 시 원래 서식으로 재해석되어 의도와 다르게 기울어질 수 있습니다.

### 2-4) 에디터 ↔ 마크다운 양방향 동기화

`NoticeEditorTextFieldSection` 에서 양방향 동기화가 일어납니다.

```swift
NoticeRichTextView(
    toolbarViewModel: viewModel.editorToolbarViewModel,
    attributedText: $viewModel.richAttributedContent,
    placeholder: "내용을 입력해주세요."
)
.onChange(of: viewModel.richAttributedContent) { _, newValue in
    viewModel.content = MarkdownSerializer.serialize(newValue)
}
```

- `richAttributedContent` : UITextView 가 편집하는 `NSAttributedString`
- `content` : 서버 송수신용 마크다운 문자열

`richAttributedContent` 가 변할 때마다 `content` 가 재직렬화됩니다. 반대로 마크다운을 에디터에 주입해야 할 때(수정 진입, AI 개선 완료)는 `MarkdownSerializer.deserialize` 로 `richAttributedContent` 를 교체합니다.

### 2-5) 툴바 상태 관리: `EditorToolbarViewModel`

툴바는 `@Observable` 로 단일 소유됩니다.

- 상태: `isBold`, `isItalic`, `isUnderline`, `isStrikethrough`, `isBlockquote`, `paragraphStyle`, `activeListStyle`, `highlightColor` 등
- 액션: `toggleBold()`, `toggleItalic()`, `toggleBlockquote()`, `applyParagraphStyle(_:)`, `applyList(_:)`, `applyIndent()`, `applyOutdent()`, `applyHighlight(color:)`, `clearHighlight()`
- 동기화: `syncFormattingState()` — 선택 영역 / `typingAttributes` 를 읽어 툴바 상태를 실제 스토리지와 일치시킴

#### 2-5-1) Italic 특수 처리

Pretendard 는 italic 변형이 없어 `oblique matrix` 로 기울임을 시뮬레이션합니다. 그런데 UIKit 은 커서 이동 시 `typingAttributes` 의 matrix 를 버리므로, italic 활성 상태를 별도 추적해야 합니다.

- 커스텀 키: `NSAttributedString.Key.editorItalic`
- 임시 플래그: `_pendingItalicEnabled` (토글 직후 UIKit 리셋 회피)
- 확인 순서: `_pendingItalicEnabled` → `.editorItalic` → `fontDescriptor.matrix.c` → `symbolicTraits`

#### 2-5-2) Blockquote 빈 단락 처리

블록 인용구는 빈 텍스트에서도 경계선이 즉시 보여야 placeholder 가 자연스럽게 숨겨집니다. 이를 위해 zero-width space(`\u{200B}`)를 인용구 속성과 함께 삽입하고, 인용구 해제 시 ZWS 전용 단락이면 완전히 제거하는 특수 경로가 있습니다(`EditorToolbarViewModel.toggleBlockquote()`).

### 2-6) 단락 속성 커스텀 키

`EditorToolbarTypes.swift` 에서 확장된 `NSAttributedString.Key` 목록입니다. 이 키들은 마크다운 직렬화/역직렬화 양쪽에서 **왕복 안정성**을 담당합니다.

| 키 | 용도 |
|----|------|
| `.editorBlockquote` | 인용구 블록 여부 |
| `.editorBlockquoteBorderColor` | 좌측 경계선 색 |
| `.editorBlockquoteBaseHeadIndent` | 인용구 적용 전 headIndent 복원용 |
| `.editorBlockquoteBaseFirstLineHeadIndent` | 인용구 적용 전 firstLineHeadIndent 복원용 |
| `.editorListStyle` | 목록 스타일 식별자 |
| `.editorItalic` | Pretendard italic 활성 플래그 |

커스텀 키가 늘어나면 `MarkdownBlockSerializer` / `MarkdownBlockParser` 양쪽에 매핑을 추가해야 왕복이 깨지지 않습니다.

### 2-7) 상세 화면 렌더링

상세 화면(`NoticeDetailView`)에서는 `MarkdownRenderedView` 가 서버 마크다운을 받아 `MarkdownSerializer.deserializeForDisplay` 로 `NSAttributedString` 을 만든 뒤 SwiftUI `Text` / `UILabel` 기반 뷰에 표시합니다. 에디터와 동일한 파서를 사용하므로 **편집 화면에서 본 서식이 상세에서 그대로** 보입니다.

---

## 3) Apple Intelligence 기반 본문 개선

### 3-1) 기능 개요

공지 에디터 우측 상단 `sparkles` 아이콘(`NoticeEditorAttachmentToolbar.swift:66`, `DefaultToolbarView.swift:136`)을 탭하면 현재 본문을 온디바이스 언어 모델로 **재작성**합니다. 핵심 내용과 의도를 유지하면서 더 명확하고 자연스러운 문장으로 다듬는 것이 목표입니다.

- 프레임워크: `FoundationModels` (`SystemLanguageModel` / `LanguageModelSession`)
- 실행 환경: 온디바이스 (Apple Intelligence 활성화 기기)
- 출력: 스트리밍(`streamResponse`)으로 생성 → 에디터에 주입

### 3-2) 진입 흐름 (3단계 오버레이)

```
[sparkles 탭]
    │
    ▼
(1) requestAIImprovement()
    │   ├── 가용성 체크 (SystemLanguageModel.default.availability)
    │   ├── 토큰 사용량 스냅샷 계산
    │   └── showAIConfirmation = true
    ▼
[AIConfirmationOverlay 표시: 토큰 게이지 + "작성하기" 버튼]
    │
    ▼ (사용자 확인)
(2) startAIImprovement() → improveContentWithAI()
    │   ├── isAIProcessing = true
    │   ├── LanguageModelSession 생성 + 프롬프트 설정
    │   ├── stream 루프: aiStreamingText 갱신 + 토큰 사용량 주기적 갱신
    │   └── 완료 시 richAttributedContent / content 교체
    ▼
[AILoadingOverlay(.processing): 스트리밍 텍스트 미리보기]
    │
    ▼ (성공)
(3) showAICompletionSummary = true
    ▼
[AILoadingOverlay(.completed): "확인" 버튼]
    │
    ▼ (사용자 확인)
dismissAICompletionSummary()  // aiStreamingText 초기화, 오버레이 닫힘
```

오버레이 합성은 `NoticeEditorPresentations.swift:34-60` 에서 수행됩니다. `showAIConfirmation` 과 `isAIProcessing || showAICompletionSummary` 가 각각 독립된 `.overlay { }` 블록으로 바인딩되어, 확인 → 처리 → 완료 전이가 부드럽게 이어집니다.

### 3-3) 가용성 체크

`SystemLanguageModel.default.availability` 가 `.available` 이 아니면 AI 기능을 차단하고 AlertPrompt 로 안내합니다.

```swift
guard case .available = SystemLanguageModel.default.availability else {
    alertPrompt = AlertPrompt(
        title: "AI 기능 사용 불가",
        message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다. 설정에서 Apple Intelligence를 활성화해주세요.",
        positiveBtnTitle: "확인"
    )
    return
}
```

체크 지점은 2 곳입니다.

1. `requestAIImprovement()` — 다이얼로그를 띄우기 전
2. `improveContentWithAI()` — 실제 실행 직전 (사용자가 확인 → 처리 시작 사이에 상태가 바뀌었을 수 있음)

### 3-4) 프롬프트와 스트리밍

```swift
let session = LanguageModelSession {
    """
    당신은 동아리 공지사항 작성 전문가입니다.
    주어진 글의 핵심 내용과 의도는 그대로 유지하면서, 더 명확하고 자연스럽게 개선하여 다시 작성해주세요.
    별도의 설명이나 메타 텍스트 없이 개선된 글만 출력하세요.
    """
}

let stream = session.streamResponse(to: plainText)
for try await partial in stream {
    fullText = partial.content
    aiStreamingText = fullText
    // ...토큰 사용량 주기적 갱신 (아래 3-5)
}
```

- 입력은 `richAttributedContent.string` 의 **trim 된 plain text**. 현재 버전은 마크다운 원문을 그대로 보내지 않고 plain text 만 사용합니다.
- 출력은 마크다운 문자열이며, 완료 직후 아래 두 줄로 에디터에 반영됩니다.

```swift
let baseFont = UIFont(name: "Pretendard-Regular", size: 16)
    ?? UIFont.preferredFont(forTextStyle: .body)
richAttributedContent = MarkdownSerializer.deserialize(fullText, baseFont: baseFont)
content = MarkdownSerializer.serialize(richAttributedContent)
```

마크다운 파이프라인을 거치므로 AI 결과도 **에디터에서 바로 편집 가능**하고, 이어지는 `.onChange` 훅으로 `content` 도 재직렬화됩니다.

### 3-5) 토큰 사용량 계산 (iOS 26.4+)

`SystemLanguageModel.contextSize` 와 `SystemLanguageModel.tokenCount(for:)` 은 iOS 26.4 이상에서만 노출됩니다. 버전 게이트는 `resolveContextSize()` 가 담당합니다.

```swift
private func resolveContextSize() -> Int? {
    guard #available(iOS 26.4, *) else { return nil }
    return SystemLanguageModel.default.contextSize
}
```

사용량 스냅샷은 `AITokenUsage` 값 타입에 담깁니다.

```swift
struct AITokenUsage: Equatable {
    let lastRunTokens: Int       // 이번 실행 소비량
    let cumulativeUsed: Int      // 에디터 세션 누적 (직전 실행 포함)
    let total: Int               // 모델 컨텍스트 윈도우
    var remaining: Int { max(0, total - cumulativeUsed) }
    var progress: Double { ... } // 0.0 ~ 1.0
}
```

스트리밍 중에는 `chunkIndex.isMultiple(of: 5)` 마다 `updateTokenUsage(session:contextSize:)` 가 호출되어 UI 게이지가 주기적으로 갱신됩니다. 마지막 chunk 이후에도 한 번 더 갱신하여 최종값을 반영합니다.

### 3-6) 일일 한도 및 SwiftData 저장

하루 단위로 누적 사용량이 기기에 저장됩니다. 다음 날 0 으로 리셋하려는 의도가 아니라, **사용량을 스케일(context size) 기준으로 추적**해서 토큰이 고갈된 날은 확인 다이얼로그에서 "작성하기" 버튼이 비활성화됩니다(`AIConfirmationOverlay.swift:60`).

- 저장 모델: `AITokenDailyUsageRecord` (`@Model` / SwiftData, CloudKit Sync 가능)
- 키: `(memberId, startOfDay(date))` 조합
- 진입 시 복원: `restoreDailyTokenUsage()` — 당일 레코드가 있으면 `aiCumulativeUsedTokens` 복원
- 완료 시 저장: `persistDailyTokenUsage(lastRunTokens:)` — 기존 레코드면 합산, 없으면 insert

저장 실패는 AI 실행 결과(본문 교체)에 영향을 주지 않습니다 — catch 블록은 의도적으로 비어 있고, 에디터 사용성을 우선합니다.

### 3-7) 확인 다이얼로그 게이지 색상 규칙

`AIConfirmationOverlay.sandwichTokenView(_:)` 에서 사용량 비율(`progress`)에 따라 게이지와 숫자 색이 단계적으로 변합니다.

| progress | 값 색상 | 게이지 색상 |
|----------|---------|-------------|
| < 0.80 | `.grey500` | `.indigo500` |
| 0.80 ~ 0.89 | `.orange` | `.orange` |
| ≥ 0.90 | `.red` | `.red` |
| `remaining == 0` | (대체 뷰) | `exclamationmark.circle.fill` + "오늘 사용 가능한 토큰을 모두 사용했어요" |

### 3-8) 로딩 오버레이 (`AILoadingOverlay`)

`.processing` 과 `.completed` 두 페이즈를 가진 단일 오버레이입니다.

- `.processing`: `sparkles` + `symbolEffect(.variableColor.iterative.reversing)` 로 애니메이션, 최신 스트리밍 텍스트 3줄까지 미리보기
- `.completed`: `checkmark.circle.fill` + "다듬기가 끝났어요" + "확인" 버튼
- 카드 외곽: `glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))` — 디자인 시스템의 Liquid Glass 규약 준수

### 3-9) 에러 처리

`improveContentWithAI()` 의 catch 블록은 AI 경로 에러를 `ErrorHandler` 로 전달합니다.

```swift
errorHandler?.handle(
    error,
    context: ErrorContext(
        feature: "Notice",
        action: "improveContentWithAI"
    )
)
```

이 시점에 `isAIProcessing = false`, `aiStreamingText = ""`, `showAICompletionSummary = false` 로 복귀시켜 오버레이가 자동으로 닫힙니다. 에러 처리 선택 기준(ErrorHandler vs Loadable vs AlertPrompt)은 프로젝트 `CLAUDE.md` 의 **에러 처리 시스템** 섹션을 따릅니다.

---

## 4) 주요 상태 프로퍼티 요약

`NoticeEditorViewModel` 의 AI/에디터 관련 프로퍼티를 한 표로 모았습니다.

| 프로퍼티 | 타입 | 설명 |
|---------|------|------|
| `richAttributedContent` | `NSAttributedString` | 에디터 편집 대상 |
| `content` | `String` | 마크다운 직렬화 결과(서버 송수신용) |
| `editorToolbarViewModel` | `EditorToolbarViewModel` | 툴바 상태 / 액션 |
| `showAIConfirmation` | `Bool` | 실행 전 확인 오버레이 표시 |
| `isAIProcessing` | `Bool` | 스트리밍 중 여부 |
| `aiStreamingText` | `String` | 스트리밍 진행 텍스트 |
| `aiTokenUsage` | `AITokenUsage?` | 토큰 사용량 스냅샷(iOS 26.4+) |
| `aiCumulativeUsedTokens` | `Int` | 에디터 세션 + 당일 누적 토큰 수 |
| `showAICompletionSummary` | `Bool` | 완료 오버레이 유지 플래그 |
| `modelContext` | `ModelContext?` | SwiftData 저장용 컨텍스트 |
| `memberId` | `Int` | 일일 사용량 키 |

---

## 5) 통합 체크리스트

공지 에디터에 마크다운/AI 기능을 연결할 때 아래를 확인합니다.

### 마크다운

- [ ] `NoticeEditorTextFieldSection` 의 `.onChange(of: richAttributedContent)` 가 `MarkdownSerializer.serialize` 로 `content` 를 갱신하는지
- [ ] 수정 진입 시 `MarkdownSerializer.looksLikeHTML(_:)` 분기와 `deserialize(_:baseFont:)` 호출 경로 확인
- [ ] 커스텀 `NSAttributedString.Key` 추가 시 `MarkdownBlockSerializer` / `MarkdownBlockParser` 양방향 매핑 여부
- [ ] 인라인 토큰 추가 시 `MarkdownRegex.inlinePatterns` **우선순위 배열** 과 `MarkdownInlineTokenKind` case 순서 일치
- [ ] `unescapeForDisplay(_:)` 를 에디터 로드 경로에서 사용하지 않았는지 (디스플레이 전용)

### AI

- [ ] `sparkles` 툴바 버튼이 `viewModel.requestAIImprovement()` 를 호출하는지
- [ ] `NoticeEditorPresentations` 에서 `AIConfirmationOverlay` 와 `AILoadingOverlay` 두 오버레이가 모두 바인딩되는지
- [ ] 에디터 진입 시 `restoreDailyTokenUsage()` 호출 여부
- [ ] `modelContext` 와 `memberId` 가 주입되는지(누락 시 일일 한도 기능이 동작하지 않음)
- [ ] `errorHandler` 주입 여부 — nil 이면 AI 에러가 무음 실패

---

## 6) 트러블슈팅

### AI 관련

- **증상**: `sparkles` 버튼을 눌러도 확인 다이얼로그가 뜨지 않음
  - 원인: 본문이 trim 후 비어 있음
  - 해결: `requestAIImprovement()` 상단의 `plainText.isEmpty` guard 확인, 사용자에게 본문 작성 안내

- **증상**: "AI 기능 사용 불가" AlertPrompt 가 노출됨
  - 원인: `SystemLanguageModel.default.availability` 가 `.available` 이 아님 (Apple Intelligence 비활성, 미지원 기기, 언어 미다운로드 등)
  - 해결: 기기 설정 → Apple Intelligence & Siri 에서 활성화. 실기기에서도 모델 다운로드가 완료되어야 함

- **증상**: 토큰 게이지가 0 또는 표시되지 않음
  - 원인: iOS 26.3 이하 기기에서는 `contextSize` / `tokenCount(for:)` 가 nil → `aiTokenUsage` 가 `nil` 로 유지됨
  - 해결: 정상 동작. 기능은 사용 가능하지만 게이지 UI 만 비노출

- **증상**: "오늘 사용 가능한 토큰을 모두 사용했어요" 가 떠서 "작성하기" 버튼이 잠김
  - 원인: `aiCumulativeUsedTokens >= contextSize`
  - 해결: 당일 한도 도달. 다음 날 0시 이후 `restoreDailyTokenUsage()` 가 새 레코드를 찾지 못해 0부터 시작

- **증상**: AI 완료 후 본문에 `**` 같은 마크다운이 그대로 보임
  - 원인: 모델 응답이 마크다운인데, `deserialize` 경로에서 baseFont 가 비정상이거나 예외 발생
  - 해결: 로그에서 `improveContentWithAI` catch 분기가 탔는지 확인, Pretendard-Regular 로딩 여부 점검

- **증상**: 스트리밍 중 앱이 버벅거림
  - 원인: `aiStreamingText` 갱신이 매 chunk 마다 SwiftUI 리렌더를 유발
  - 해결: 현재 3줄 `lineLimit` 으로 뷰 비용을 제한하고 있음. 로직을 수정할 때 `streamingLineLimit` 를 임의로 늘리지 말 것

### 마크다운 관련

- **증상**: `**text**` 로 작성했는데 에디터에서 굵게가 아닌 `**` 그대로 표시됨
  - 원인: 토큰 우선순위 충돌 또는 이스케이프 누락
  - 해결: `MarkdownRegex.inlinePatterns` 의 순서와 `MarkdownInlineTokenKind` 선언 순서가 어긋나지 않았는지 확인

- **증상**: 역직렬화 시 `\*not bold\*` 같은 입력이 기울어져 표시됨
  - 원인: 에디터 로드 경로에서 전체 문자열을 `unescapeForDisplay` 로 사전 처리함
  - 해결: 에디터 로드는 반드시 `deserialize(_:baseFont:)` 만 사용. 사전 unescape 제거

- **증상**: 공지 수정 화면 진입 시 HTML 공지가 깨져 보임
  - 원인: 레거시 공지가 HTML 로 저장됨 → `MarkdownSerializer.looksLikeHTML(_:)` 분기 미처리
  - 해결: 수정 진입 로직에서 HTML 여부 판별 후 전용 파서로 분기

- **증상**: 인용구 안에서 엔터를 눌렀더니 인용구가 해제됨
  - 원인: `toggleBlockquote()` 의 ZWS 제거 분기에 걸림
  - 해결: 빈 ZWS 단락 외에는 속성이 유지되는지 `.paragraphStyle` / `.editorBlockquote` 키 디버깅

- **증상**: 이탤릭 토글 직후 바로 다음 글자가 이탤릭으로 입력되지 않음
  - 원인: UIKit 이 `typingAttributes` 의 oblique matrix 를 버림
  - 해결: `_pendingItalicEnabled` + `.editorItalic` 커스텀 키 reinject 경로 확인
