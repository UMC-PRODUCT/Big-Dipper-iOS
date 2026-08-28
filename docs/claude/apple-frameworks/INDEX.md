# Apple 프레임워크 가이드 인덱스

> Apple Xcode 27에 내장된 AI 어시스턴트용 프레임워크 문서 **전량**입니다.
> 출처: [artemnovichkov/xcode-27-system-prompts](https://github.com/artemnovichkov/xcode-27-system-prompts)
> (이전 출처였던 `xcode-26-system-prompts` 는 더 이상 갱신되지 않는다.)
>
> **사용법**: Apple 프레임워크 API를 다룰 때 아래 해당 문서를 `Read` 로 열어
> 정확한 API 시그니처/패턴/가용성을 확인한 뒤 코드를 작성한다.
> 이 문서들은 컨텍스트 절약을 위해 **자동 로드하지 않고 필요 시에만** 읽는다.
>
> ⚠️ **가용성 주의**: 이 프로젝트의 Deployment Target은 **iOS 26.4** 다.
> `*-whats-new-27` 계열이 설명하는 SDK 27 API는 그대로 쓰면 컴파일되지 않으므로
> `@available` / `if #available` 게이팅이 필요하다. 각 문서의 "Availability" 표를 반드시 확인할 것.
>
> ⚠️ **우선순위**: 여기 문서는 전부 Apple 원문이며 **모델의 학습 지식보다 우선**한다.
> 다만 이 저장소의 **절대 규칙(`CLAUDE.md`)이 더 우선**한다 — 충돌 시 프로젝트 규약을 따른다.

## 구성

| 위치 | 내용 |
|------|------|
| `*.md` (이 폴더 바로 아래) | 프레임워크 개별 가이드 20종 — 업스트림 `AdditionalDocumentation/` |
| `skills/<이름>/SKILL.md` | Apple이 작성한 스킬팩 진입 문서 9종 — 언제 어떤 reference를 읽어야 하는지 안내 |
| `skills/<이름>/references/*.md` | 스킬팩 본문 66종 — 실제 API 설명·코드 예시 |
| `skills/audit-xcode-security-settings/scripts/` | 스킬팩에 딸린 보조 스크립트 |

---

## 1. 이 프로젝트에 특히 관련 높은 문서

UMC 앱은 SwiftUI + Liquid Glass + Widget + (Apple Intelligence) 기반이라 아래가 우선순위가 높다.

| 문서 | 다룰 때 |
|------|---------|
| `SwiftUI-Implementing-Liquid-Glass-Design.md` | `glassEffect`, `GlassEffectContainer`, Glass variant — **디자인 시스템 핵심** |
| `skills/swiftui-specialist/` | **버전 무관 SwiftUI 베스트 프랙티스** — `@Observable` 무효화 범위, `ForEach`/`List` identity, 뷰 구조 분리, Environment 성능 함정. 코드 리뷰·성능 튜닝 시 1순위 |
| `WidgetKit-Implementing-Liquid-Glass-Design.md` | `UMCAppWidget` 위젯에 Liquid Glass 적용 |
| `SwiftUI-New-Toolbar-Features.md` | 툴바 신규 API (`ToolBar/` 헬퍼 작업 시) |
| `SwiftUI-Styled-Text-Editing.md` | `ArticleTextField` 등 리치 텍스트 입력/편집 |
| `Foundation-AttributedString-Updates.md` | AttributedString 신규 기능 (마크다운/스타일 텍스트) |
| `Swift-Concurrency-Updates.md` | async/await, actor, `@MainActor` 동시성 패턴 |
| `SwiftData-Class-Inheritance.md` | SwiftData 모델 클래스 상속 |
| `FoundationModels-Using-on-device-LLM-in-your-app.md` | 온디바이스 LLM (Apple Intelligence 기능) |
| `skills/swiftui-whats-new-27/` | SDK 27 SwiftUI 신규 API·deprecation (⚠️ 가용성 게이팅 필요) |
| `skills/app-intents-specialist/` | App Intents(Siri/단축어) 작성 규약 — The Ping·딥링크 확장 시 |
| `Widgets-for-visionOS.md` | visionOS 위젯 |

---

## 2. 프레임워크 개별 가이드 (20종)

업스트림 `AdditionalDocumentation/` 그대로. Xcode 26 시절과 내용이 동일하다(바이트 단위 일치 확인).

| 문서 | 프레임워크 / 다룰 때 |
|------|---------------------|
| `SwiftUI-Implementing-Liquid-Glass-Design.md` | SwiftUI Liquid Glass |
| `UIKit-Implementing-Liquid-Glass-Design.md` | UIKit Liquid Glass |
| `AppKit-Implementing-Liquid-Glass-Design.md` | AppKit(macOS) Liquid Glass |
| `WidgetKit-Implementing-Liquid-Glass-Design.md` | WidgetKit Liquid Glass |
| `SwiftUI-New-Toolbar-Features.md` | SwiftUI 툴바 신규 기능 |
| `SwiftUI-Styled-Text-Editing.md` | 리치 텍스트 편집 |
| `SwiftUI-WebKit-Integration.md` | SwiftUI + WebKit |
| `SwiftUI-AlarmKit-Integration.md` | SwiftUI + AlarmKit |
| `Foundation-AttributedString-Updates.md` | AttributedString 갱신 |
| `Swift-Concurrency-Updates.md` | Swift 동시성 갱신 |
| `Swift-InlineArray-Span.md` | `InlineArray` / `Span` |
| `Swift-Charts-3D-Visualization.md` | Swift Charts 3D |
| `SwiftData-Class-Inheritance.md` | SwiftData 클래스 상속 |
| `FoundationModels-Using-on-device-LLM-in-your-app.md` | 온디바이스 LLM |
| `AppIntents-Updates.md` | AppIntents 갱신 (Siri/단축어 노출) |
| `MapKit-GeoToolbox-PlaceDescriptors.md` | MapKit GeoToolbox |
| `StoreKit-Updates.md` | StoreKit (인앱 결제) |
| `Implementing-Visual-Intelligence-in-iOS.md` | Visual Intelligence |
| `Implementing-Assistive-Access-in-iOS.md` | 접근성 (Assistive Access) |
| `Widgets-for-visionOS.md` | visionOS 위젯 |

---

## 3. Apple 스킬팩 (9종 · reference 66종)

각 스킬은 `SKILL.md`(언제 무엇을 읽을지 안내) + `references/*.md`(본문)로 구성된다.
**먼저 `SKILL.md` 를 읽고, 필요한 reference만 골라 읽는다.**

### 3-1. `skills/swiftui-specialist/` — SwiftUI 베스트 프랙티스 (버전 무관)

Apple이 직접 쓴 SwiftUI 정석. 성능·구조·데이터 흐름 판단이 필요할 때 최우선.

| reference | 내용 |
|-----------|------|
| `structure.md` | 뷰를 별도 `View` 구조체로 쪼갤 때 vs computed property, init 비용, 단일 자식 `Group` 안티패턴 |
| `dataflow.md` | `@State`/`@Binding`/모델 전달, `@Observable` 권장(`ObservableObject` 대신), 프로퍼티 단위 관찰 추적의 함정, `.onChange` 부수효과 격리 |
| `environment.md` | `@Environment`·`@Entry` 성능 함정 — 클로저/클래스 기본값, 고빈도 갱신 경고 |
| `modifiers.md` | 조건부 modifier는 `if`/`else` 분기보다 삼항, `AnyShapeStyle` 활용 |
| `foreach.md` | `ForEach`/`List`/`Table` 요소 identity, `id: \.self`·인덱스·오프셋 안티패턴, row 구조가 `List` 성능에 미치는 영향 |
| `animations.md` | 커스텀 `Animatable` 타입 (`@Animatable` 매크로, `animatableData`) |
| `localization.md` | `LocalizedStringKey` vs `LocalizedStringResource`, 패키지/프레임워크의 `bundle: #bundle`, 포맷 스타일, RTL |
| `soft-deprecation.md` | soft-deprecated API 판별법과 마이그레이션 시점 |
| `soft-deprecated-apis.md` | soft-deprecated SwiftUI API 전체 목록 + 대체 API (검색용) |

### 3-2. `skills/swiftui-whats-new-27/` — SDK 27 SwiftUI 신규/변경

⚠️ 전부 iOS 27 API. iOS 26.4 타깃에서는 가용성 게이팅 필수.

| reference | 내용 |
|-----------|------|
| `state-macro.md` | `@State` 가 property wrapper → **매크로**로 전환. SDK 갱신 후 "used before being initialized" 등 컴파일 에러의 정확한 해법(초기화 순서 변경은 오답) |
| `content-builder.md` | 결과 빌더 `@ContentBuilder` 통합 — `overlay`/`background` `ShapeStyle` 오버로드 모호성, Swift Charts 타입 체크 성능 회귀 |
| `reorderable.md` | 임의 컨테이너 드래그 재정렬 (`.reorderable()` + `.reorderContainer(for:)`, `ReorderDifference`) |
| `toolbar.md` | 툴바 오버플로 제어 — `visibilityPriority`, `ToolbarOverflowMenu`, `.topBarPinnedTrailing`, `toolbarMinimizeBehavior` |
| `swipe-actions.md` | `List` 밖(ScrollView·LazyVStack·LazyVGrid)에서의 스와이프 액션 — `swipeActionsContainer()` |
| `item-binding.md` | `confirmationDialog`/`alert` 의 `item: Binding<T?>` 오버로드 (`sheet(item:)` 형태) |
| `async-image.md` | `AsyncImage` HTTP 캐싱 기본 적용, `AsyncImage(request:)`, `asyncImageURLSession(_:)` |
| `document-based-apps.md` | 신규 `ReadableDocument`/`WritableDocument` 프로토콜 — 파일 URL 직접 접근·백그라운드 읽기/쓰기 (`FileDocument` 대체) |
| `deprecations.md` | SDK 27에서 **hard-deprecated** 된 API 목록 (soft-deprecated 는 `swiftui-specialist/references/soft-deprecated-apis.md`) |

### 3-3. `skills/app-intents-specialist/` — App Intents 규약 (버전 무관)

| reference | 내용 |
|-----------|------|
| `execution-model.md` | `perform()` 은 `@MainActor` 아님(UI는 hop), 재시도 가능하므로 되돌릴 수 없는 작업은 마지막에·멱등하게, 반환은 `.result(...)` |
| `entities-and-queries.md` | `AppEntity.id` 안정성, `entities(for:)` 배치 조회, `EntityStringQuery` 필터 미적용, `@Property` 만 시스템 노출 |
| `entity-property-queries.md` | Shortcuts "Find X where…" 용 `EntityPropertyQuery` — 술어 파싱은 프레임워크, 실행은 앱 |
| `app-enum.md` | `AppEnum` raw value는 문자열로 영속 — 재번호/재정렬 금지, `caseDisplayRepresentations` 누락 시 런타임 fatalError |
| `parameters.md` | `requestValue` vs `needsValueError`, non-optional `AppEnum` 자동 disambiguation |
| `parameter-summaries.md` | `Summary(...)` 에 넣은 파라미터만 Shortcuts 편집기에 노출, `When`/`Switch` 조건부 표시 |
| `dependencies.md` | `@Dependency` 는 `Sendable` + 앱 시작 시 등록 필수(미등록=fatalError), intent/query 에만 부착 |
| `results-and-errors.md` | `CustomLocalizedStringResourceConvertible` 에러만 실제 메시지 노출, iOS 18+ `AppIntentError.*` |
| `donation.md` | 앱 내 동작은 자동 기부되지 않음 — `IntentDonationManager.shared.donate` 직접 호출 |
| `localization.md` | 사용자 노출 문자열은 **리터럴** `LocalizedStringResource` (런타임 `String` 은 키 추출 불가) |
| `app-shortcut-phrases.md` | `shortTitle`/`systemImageName` 필수, `\(.applicationName)` 없으면 문구가 조용히 무시됨 |
| `url-representation.md` | `OpenIntent` / `OpenURLIntent` / `URLRepresentableEntity` — 딥링크·유니버설 링크 |
| `configuration-intents.md` | `WidgetConfigurationIntent`/`ControlConfigurationIntent` 는 파라미터 전용(`perform()` 없음) |
| `factoring.md` | `AppEnum`(고정 집합) vs `AppEntity`+query(동적) vs 평범한 `@Parameter`, 작업 단위 1 intent |

### 3-4. `skills/app-intents-whats-new-27/` — iOS 26/27 App Intents 신규

| reference | 내용 |
|-----------|------|
| `execution-modes.md` | `supportedModes`/`IntentModes`(background/foreground), deprecated `openAppWhenRun` 대체, `continueInForeground`, `UndoableIntent`, `LongRunningIntent`(27) |
| `interactive-snippets.md` | `SnippetIntent` 로 상호작용 스니펫 반환, `Button(intent:)`/`Toggle(isOn:intent:)`, 재실행되므로 부수효과 금지 |
| `requestchoice.md` | `perform()` 중 선택지 제시 — `requestChoice(between:dialog:)`, `IntentChoiceOption` |
| `visual-intelligence.md` | 카메라/스크린샷 검색 노출 — `IntentValueQuery` + `SemanticContentDescriptor`(`import VisualIntelligence`) + `@UnionValue` |
| `onscreen-entities.md` | 화면 위 "이것" 해석 — `NSUserActivity.appEntityIdentifier`, `AppEntityUIElement` |
| `spotlight-indexing.md` | `@Property`/`@ComputedProperty`/`@DeferredProperty(indexingKey:)` 로 Spotlight 매핑, `IndexedEntityQuery`(27) |
| `convenience-properties.md` | `@ComputedProperty`(동기) / `@DeferredProperty`(async) 읽기 전용 파생 프로퍼티 |
| `schema-adoption.md` | Apple Intelligence 스키마 — `@AppIntent(schema:)` 계열. ⚠️ `@AssistantIntent` 계열은 deprecated |
| `relevance-and-context.md` | `RelevantEntities` + `AppEntityContext` 로 지금 관련 있는 엔티티 힌트 (27) |
| `cross-device-and-ownership.md` | `SyncableEntity`/`EntityOwnership` — 기기 간 안정 식별자·공유 소유권 (27) |
| `system-shortcuts.md` | `SystemShortcut` + `RunSystemShortcutIntent` — 위젯 구성 안 `Button(intent:)` 전용 (27, iPhone/iPad) |
| `testing.md` | `AppIntentsTesting` 프레임워크로 intent 단위 테스트 (27) |
| `entity-collection.md` | `EntityCollection<Entity>` — 대량 엔티티를 id 우선으로 다뤄 강제 전량 해석 회피 (27) |
| `union-values.md` | `AppUnionValue` — `@UnionValue` 타입을 Shortcuts 파라미터로 노출 (27) |

### 3-5. `skills/uikit-app-modernization/` — UIKit 멀티윈도우 현대화

레거시 전역 상태 API를 컨텍스트 기반 API로 교체. 이 프로젝트는 SwiftUI 중심이라 우선순위는 낮다.

| reference | 내용 |
|-----------|------|
| `uiscreen-task.md` | `UIScreen.main` 제거 및 컨텍스트별 대체 |
| `orientation-task.md` | 레이아웃용 orientation 체크 → size class / window bounds |
| `scene-lifecycle-task.md` | AppDelegate → SceneDelegate 마이그레이션 |
| `safe-area-task.md` | 하드코딩 inset → safe area, 비대칭 safe area 대응 |

### 3-6. `skills/building-document-based-swiftui-applications/` — 문서 기반 SwiftUI 앱

SDK 27 `Document` 프로토콜 기반. 현재 UMC 앱에는 해당 없음(참고용).

| reference | 내용 |
|-----------|------|
| `creating-document-apps.md` | `DocumentGroup`, `ReadableDocument`/`WritableDocument`, FileWrapper·패키지 문서, undo, 진행률, 커스텀 `UTType` |
| `migrating-document-apps.md` | `FileDocument`/`ReferenceFileDocument` → `Document` 마이그레이션 (before/after 예시) |
| `uniform-type-identifiers.md` | 커스텀 `UTType` 선언·검증 — 상속 계층, export vs import, `uttype` CLI |

### 3-7. `skills/audit-xcode-security-settings/` — Xcode 보안 빌드 설정 감사

컴파일러 경고·정적 분석·Enhanced Security를 단계적으로 켜는 워크플로. 릴리스 하드닝 검토 시 참고.

| reference | 내용 |
|-----------|------|
| `security-settings-reference.md` | 이 스킬이 추적하는 보안 빌드 설정·entitlement 정본 목록 |
| `settings-and-entitlements-catalog.md` | 적용 순서대로 정리한 전체 카탈로그 — 빌드 설정·값·CLI 플래그·적용 언어 범위 (필터 스크립트가 이 파일에서 매크로명을 추출) |
| `reading-build-settings.md` | `GetTargetBuildSettings` 스키마, 필터 스크립트 사용법, 감사 표 구성 |
| `enhanced-security.md` | Enhanced Security capability — 빌드 설정·entitlement·지원 product type |
| `pointer-authentication.md` | arm64e 포인터 서명 — 지원 플랫폼·호환성 |
| `universal-binaries-for-libraries.md` | 라이브러리/프레임워크 유니버설 바이너리 (`ONLY_ACTIVE_ARCH = NO`) |
| `security-compiler-warnings.md` | Enhanced Security가 켜는 보안 관련 컴파일러 경고 |
| `cpp-hardening.md` | C++ 표준 라이브러리 하드닝, bounds-safe buffers |
| `typed-allocators.md` | 타입 인지 할당자 / `hardened-heap` |
| `stack-zero-init.md` | 스택 변수 런타임 zero-init |
| `readonly-platform-memory.md` | dyld 상태 읽기 전용 보호 |
| `runtime-restrictions.md` | dylib · Mach 메시지 플랫폼 제한 |
| `hardware-memory-tagging.md` | MTE entitlement 및 지원 하드웨어 |
| `additional-settings.md` | 기본값 외 선택적 진단 설정 (오탐 가능) |
| `adoption-strategy.md` | 검증 순서 권장안 (위험 낮은 것 → 노력 큰 것) |
| `decision-document.md` | `xcode-security-settings.md` 결정 문서 유지 방법 |

보조 스크립트: `scripts/filter_build_settings.py` — 빌드 설정 JSON을 추적 대상 매크로만 남기고 필터.

### 3-8. `skills/c-bounds-safety/` · 3-9. `skills/adopt-c-bounds-safety/` — C `-fbounds-safety`

C 코드용 경계 안전성 언어 확장. 이 프로젝트는 순수 Swift라 **현재 해당 없음**.
두 스킬은 같은 주제이며 `references/adoption-strategies.md` 와 `SKILL.md` 만 다르다
(`adopt-` 쪽이 기존 코드 도입 워크플로에 초점). 업스트림에 둘 다 존재해 그대로 보존했다.

| reference (양쪽 공통) | 내용 |
|-----------|------|
| `language-overview.md` | 포인터 종류·`__counted_by` 등 어노테이션·규칙 |
| `adoption-strategies.md` | 기존 C 프로젝트 도입 워크플로 (full / header-only 모드) |
| `common-patterns-and-pitfalls.md` | 실제 도입에서 만나는 레시피와 안티패턴 |
| `build-settings.md` | 컴파일러 플래그·Xcode 빌드 설정·soft trap 모드·`ptrcheck.h` |
| `runtime-debugging.md` | 경계 위반 런타임 디버깅 — trap 동작, LLDB, 워치포인트, 크래시 로그 |

---

## 4. 반영하지 않은 업스트림 자료

업스트림 나머지 파일은 **Xcode 내장 어시스턴트의 내부 프롬프트 배관**이라 프레임워크 레퍼런스로서의 가치가 없어 가져오지 않았다. 필요하면 원본을 직접 본다.

| 미반영 자료 | 사유 |
|------------|------|
| `*.idechatprompttemplate` 중 스킬 진입점이 아닌 것 (`BasicSystemPrompt`, `Query`, `IntegratorSystemPrompt`, `CodingToolTemplate*` 등 40여 개) | Xcode 채팅 UI의 시스템 프롬프트·템플릿. API 문서가 아님 |
| `AgentVersions.plist` · `IDEIntelligenceChat.xcplugindata` · `bert-estimate.vocab` | 바이너리/설정 자산 |
| `README.md` | 업스트림 저장소 안내문 |

## 5. 갱신 방법

업스트림이 다시 바뀌면 아래를 실행한 뒤 이 인덱스의 표를 손본다.

```bash
git clone --depth 1 https://github.com/artemnovichkov/xcode-27-system-prompts.git /tmp/x27
SRC=/tmp/x27
DEST=docs/claude/apple-frameworks

cp "$SRC"/AdditionalDocumentation/*.md "$DEST"/

shopt -s nullglob
cd "$SRC"
for t in *.idechatprompttemplate; do
    name="${t%.idechatprompttemplate}"
    refs=("$name"-ref-*.md.packaged)
    [ ${#refs[@]} -gt 0 ] || continue          # -ref- 동반 파일이 있는 것만 스킬팩
    mkdir -p "$OLDPWD/$DEST/skills/$name/references"
    cp "$t" "$OLDPWD/$DEST/skills/$name/SKILL.md"
    for r in "${refs[@]}"; do
        ref="${r#$name-ref-}"; ref="${ref%.packaged}"
        cp "$r" "$OLDPWD/$DEST/skills/$name/references/$ref"
    done
    for s in "$name"-script-*; do
        mkdir -p "$OLDPWD/$DEST/skills/$name/scripts"
        cp "$s" "$OLDPWD/$DEST/skills/$name/scripts/${s#$name-script-}"
    done
done
```

- `.idechatprompttemplate` → `SKILL.md`, `<스킬>-ref-<이름>.md.packaged` → `references/<이름>.md` 로 정규화한다.
  (확장자만 바꾼 것이고 내용은 무손실 복사)
- Xcode 28 이 나오면 업스트림 저장소 이름도 `xcode-28-system-prompts` 로 바뀔 가능성이 높다.
