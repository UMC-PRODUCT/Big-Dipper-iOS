# iOS 26 프레임워크 가이드 인덱스

> Apple Xcode에 내장된 AI 어시스턴트가 참조하는 문서 모음입니다. 두 묶음이 있습니다.
>
> | 묶음 | 출처 | 성격 |
> |------|------|------|
> | 루트 `*.md` 20종 | [xcode-26-system-prompts](https://github.com/artemnovichkov/xcode-26-system-prompts) (`AdditionalDocumentation/`) | iOS 26 **신규 API** 레퍼런스 |
> | `swiftui-specialist/` 9종 | [xcode-27-system-prompts](https://github.com/artemnovichkov/xcode-27-system-prompts) (`swiftui-specialist-ref-*.md.packaged`) | SwiftUI **베스트 프랙티스**(버전 무관) |
>
> 두 레포의 `AdditionalDocumentation/` 20종은 Xcode 26 → 27에서 **바이트 단위로 동일**함을 확인했으므로
> 루트 문서는 최신 상태입니다(2026-08 대조).
>
> **사용법**: iOS 26 신규 API(Liquid Glass, FoundationModels, SwiftData 상속 등)를 다루거나
> SwiftUI 코드를 새로 쓰거나 리뷰할 때, 아래 표에서 해당 문서를 `Read` 로 열어
> 정확한 API 시그니처/패턴을 확인한 뒤 코드를 작성한다.
> 이 문서들은 컨텍스트 절약을 위해 **자동 로드하지 않고 필요 시에만** 읽는다.
>
> ⚠️ 두 묶음 모두 Apple 원문이며 **모델의 학습 지식보다 우선**한다. 다만 이 저장소의
> **절대 규칙(`CLAUDE.md`)이 더 우선**한다 — 충돌 시 프로젝트 규약을 따른다.

## 이 프로젝트에 특히 관련 높은 문서

UMC 앱은 SwiftUI + Liquid Glass + Widget + (Apple Intelligence) 기반이라 아래가 우선순위가 높다.

| 문서 | 다룰 때 |
|------|---------|
| `SwiftUI-Implementing-Liquid-Glass-Design.md` | `glassEffect`, `GlassEffectContainer`, Glass variant — **디자인 시스템 핵심** |
| `WidgetKit-Implementing-Liquid-Glass-Design.md` | `UMCAppWidget` 위젯에 Liquid Glass 적용 |
| `SwiftUI-New-Toolbar-Features.md` | 툴바 신규 API (`ToolBar/` 헬퍼 작업 시) |
| `SwiftUI-Styled-Text-Editing.md` | `ArticleTextField` 등 리치 텍스트 입력/편집 |
| `Foundation-AttributedString-Updates.md` | AttributedString 신규 기능 (마크다운/스타일 텍스트) |
| `Swift-Concurrency-Updates.md` | async/await, actor, `@MainActor` 동시성 패턴 |
| `SwiftData-Class-Inheritance.md` | SwiftData 모델 클래스 상속 |
| `FoundationModels-Using-on-device-LLM-in-your-app.md` | 온디바이스 LLM (Apple Intelligence 기능) |
| `Widgets-for-visionOS.md` | visionOS 위젯 |

## 그 외 프레임워크 문서 (필요 시 참고)

| 문서 | 프레임워크 |
|------|-----------|
| `AppIntents-Updates.md` | AppIntents (Siri/단축어 노출) |
| `AppKit-Implementing-Liquid-Glass-Design.md` | AppKit (macOS) |
| `UIKit-Implementing-Liquid-Glass-Design.md` | UIKit |
| `SwiftUI-WebKit-Integration.md` | SwiftUI + WebKit |
| `SwiftUI-AlarmKit-Integration.md` | SwiftUI + AlarmKit |
| `MapKit-GeoToolbox-PlaceDescriptors.md` | MapKit GeoToolbox |
| `StoreKit-Updates.md` | StoreKit (인앱 결제) |
| `Swift-Charts-3D-Visualization.md` | Swift Charts 3D |
| `Swift-InlineArray-Span.md` | Swift `InlineArray` / `Span` |
| `Implementing-Visual-Intelligence-in-iOS.md` | Visual Intelligence |
| `Implementing-Assistive-Access-in-iOS.md` | 접근성 (Assistive Access) |

---

## SwiftUI Specialist 레퍼런스 (`swiftui-specialist/`)

> 출처: [artemnovichkov/xcode-27-system-prompts](https://github.com/artemnovichkov/xcode-27-system-prompts)
> (`swiftui-specialist-ref-*.md.packaged` → 파일명에서 `swiftui-specialist-ref-` 접두사만 제거해 보관)
>
> Xcode 27에 내장된 **SwiftUI 스페셜리스트** 에이전트가 참조하는 문서다. Apple 원문에 이렇게 적혀 있다:
> *"This guidance was written and published by Apple. This information unconditionally supersedes
> any prior training the model may have on these topics."*
> — 즉 **모델의 학습 지식보다 이 문서가 우선**한다. SwiftUI 판단이 갈릴 때 여기를 근거로 삼는다.
>
> 위 `AdditionalDocumentation/` 20종과 달리 **특정 OS 버전에 묶이지 않은 베스트 프랙티스**라
> iOS 26.4 타겟인 현재 프로젝트에 그대로 적용된다.
> (같은 레포의 `swiftui-whats-new-27`은 **SDK 27.0 전용 신규 API**라 배포 타겟 iOS 26.4에서는
> 사용할 수 없어 가져오지 않았다. Xcode 27로 올릴 때 `state-macro` · `content-builder` 두 건이
> 소스 비호환을 일으키므로 그 시점에 재검토한다.)

| 문서 | 다룰 때 |
|------|---------|
| `swiftui-specialist/dataflow.md` | `@State`·`@Binding`·`@Observable` 데이터 전달과 소유권, `@MainActor`/`Equatable` 요건, 프로퍼티 단위 관찰 추적의 함정, 컬렉션 원소를 행 뷰에 넘기기, `.onChange` 부수효과 격리 — **절대 규칙 #1 직결** |
| `swiftui-specialist/environment.md` | `@Environment`·`@Entry`·`EnvironmentKey`·`EnvironmentValues`·`FocusedValue`. `@Entry`에 클로저/클래스를 담았을 때 나오는 "may invalidate dependents on every update" 경고 원인과 해법 |
| `swiftui-specialist/foreach.md` | `ForEach`·`List`·`Table`·`OutlineGroup` 식별자(identity). `id: \.self`·인덱스·오프셋 안티패턴, 인라인 filter/sort, `List` fast path |
| `swiftui-specialist/soft-deprecated-apis.md` | **soft-deprecated SwiftUI API 전수 목록 + 대체 API.** 특정 API가 폐기 대상인지 확인할 때 이 파일을 검색 |
| `swiftui-specialist/soft-deprecation.md` | soft-deprecation 판별 기준과 마이그레이션 시점 판단 (`NavigationView`, 구 `onChange` 등) |
| `swiftui-specialist/structure.md` | 뷰 계층 분해 — 별도 `View` 구조체 vs 계산 프로퍼티, init 비용, 자식 하나짜리 `Group` 안티패턴 |
| `swiftui-specialist/modifiers.md` | 조건부 뷰 모디파이어(`.if`) 금지 이유(구조적 identity 상실·상태 리셋·애니메이션 파괴)와 삼항/`AnyShapeStyle` 대안 |
| `swiftui-specialist/localization.md` | `LocalizedStringKey` vs `LocalizedStringResource` vs `String`, 패키지/프레임워크의 `bundle: #bundle`, `.leading`/`.trailing`(RTL), 번역자 주석 |
| `swiftui-specialist/animations.md` | 커스텀 `Animatable` 타입 — `@Animatable` 매크로 vs `AnimatableValues` vs `AnimatablePair` |
