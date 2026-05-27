# iOS 26 프레임워크 가이드 인덱스

> Apple Xcode 26에 내장된 AI 어시스턴트용 프레임워크 문서 모음입니다.
> 출처: [artemnovichkov/xcode-26-system-prompts](https://github.com/artemnovichkov/xcode-26-system-prompts) (`AdditionalDocumentation/`)
>
> **사용법**: iOS 26 신규 API(Liquid Glass, FoundationModels, SwiftData 상속 등)를 다룰 때
> 아래 해당 문서를 `Read` 로 열어 정확한 API 시그니처/패턴을 확인한 뒤 코드를 작성한다.
> 이 문서들은 컨텍스트 절약을 위해 **자동 로드하지 않고 필요 시에만** 읽는다.

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
