# Build & Run + Tuist 모듈 구조

> 빌드 명령, Tuist 모듈화 구조, 의존성 방향에 대한 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

## Build & Run

프로젝트는 `AppProduct/`(레거시 xcodeproj)와 `UMCApp/`(Tuist 기반) **두 축**으로 관리됩니다.
신규 작업은 `UMCApp/`를 기본으로 사용합니다.

### AppProduct (xcodeproj)

```bash
# Xcode로 빌드 (권장)
open AppProduct/AppProduct.xcodeproj

# CLI 빌드
xcodebuild -project AppProduct/AppProduct.xcodeproj -scheme AppProduct -configuration Debug build

# 테스트 실행
xcodebuild -project AppProduct/AppProduct.xcodeproj -scheme AppProduct test
```

### UMCApp (Tuist)

Tuist 버전은 `UMCApp/mise.toml` 로 팀 전원 고정됩니다. Makefile이 `mise exec --` 래퍼를 제공하므로 **로컬 tuist 버전 차이가 발생하지 않습니다**.

```bash
cd UMCApp

# 최초 1회 (신규 팀원)
brew install mise      # mise가 없다면
make bootstrap         # mise.toml 기반 tuist 설치
make install           # SPM 의존성

# 일상 작업
make generate          # .xcworkspace 생성
make open              # Xcode 열기 (없으면 자동 generate)
make test              # xcodebuild 테스트
make doctor            # 환경 진단 (mise/tuist/xcode 버전)
make reset             # 꼬였을 때 전체 초기화
make help              # 전체 타겟 목록
```

자세한 사용법은 `UMCApp/MAKEFILE_GUIDE.md` 참고.

## Tuist 모듈 구조 (UMCApp)

`UMCApp/` 폴더는 Tuist 기반의 별도 모듈화 프로젝트입니다. `AppProduct/`와 병행하여 관리됩니다.

### 버전 관리 & 빌드 래퍼

| 파일 | 역할 |
|------|------|
| `mise.toml` | Tuist 버전 고정 (현재 `4.155.0`) — 팀 전원 동일 버전 보장 |
| `Makefile` | `mise exec -- tuist …` 래퍼. 모든 Tuist/xcodebuild 명령의 **표준 진입점** |
| `MAKEFILE_GUIDE.md` | 팀원용 사용 가이드 |

> Tuist 버전을 올릴 때는 **`mise.toml` 만** 수정하고 PR 본문에 릴리스 노트를 첨부합니다.
> Makefile / 로컬 tuist 설치는 손대지 않습니다.

### 전체 구조

```
UMCApp/
├── Makefile                       # 빌드/생성 래퍼 (mise exec 기반)
├── MAKEFILE_GUIDE.md              # 팀원용 사용 가이드
├── mise.toml                      # tuist 버전 고정
├── Project.swift                  # 앱 타겟 정의
├── Workspace.swift                # 전체 워크스페이스 (Core/*, Features/* glob + Widget/Watch)
├── Tuist.swift                    # Tuist 시스템 설정
├── Tuist/
│   ├── Package.swift              # SPM 외부 의존성 (Moya, Kingfisher)
│   └── ProjectDescriptionHelpers/
│       ├── Project+Core.swift     # Core 모듈 공통 헬퍼
│       └── Project+Feature.swift  # Feature 모듈 공통 헬퍼
├── Core/                          # 8개 공유 인프라 모듈
│   ├── Foundation/                # 기반 유틸리티, Config
│   ├── Network/                   # 네트워크 레이어 (Moya)
│   ├── DesignSystem/              # 디자인 토큰, 색상
│   ├── UIComponents/              # 공용 UI 컴포넌트 (Kingfisher)
│   ├── DI/                        # 의존성 주입 컨테이너
│   ├── NearbyExchange/            # 근거리 명함 교환 인프라
│   ├── WatchConnectivity/         # iOS ↔ watchOS 통신
│   └── WidgetShared/              # Widget-App 공유 모델
├── Features/                      # 8개 기능 모듈
│   ├── Activity/
│   ├── Auth/
│   ├── Badge/
│   ├── BusinessCard/              # 전자명함 (2D 카드 UI · QR · 근거리 교환)
│   ├── Community/
│   ├── Home/
│   ├── MyPage/
│   └── Notice/
├── UMCAppWidget/                  # Widget Extension 타겟
└── UMCWatchApp/                   # watchOS Companion App 타겟
```

### 모듈 의존성 방향

```
App Target (UMCApp)
    ↓
Feature Presentation  (Domain + CoreDesignSystem + CoreUIComponents)
    ↓
Feature Domain        (UMCFoundation)
Feature Data          (Domain + CoreNetwork + UMCFoundation)
    ↓
Core Modules          (Foundation / Network / DesignSystem / UIComponents / DI)
    ↓
External Packages     (Moya 15.0.3 / Kingfisher 8.6.1)
```

> **경계 정책 — BusinessCard**: MyPage·Home·Community·Activity·Auth 등 명함을 노출하는 Feature는 `BusinessCardPresentation`만 링크해 카드 UI(`BusinessCardFaceView` 등)를 재사용하며, 카드 화면을 자체 구현하지 않는다. 2D SwiftUI(`BusinessCardFaceView`)는 여전히 정본 카드 UI이고, 이 경계 자체는 렌더링 방식과 무관하게 유효하다.
>
> 렌더링 이력: 초기 구상이던 RealityKit(3D)은 한 차례 폐기됐다(#1196에서 ARKit·RealityKit 링크 해제). 이후로는 2D SwiftUI가 유일한 렌더링 경로였다. 그런데 #1245 Phase 0 스파이크가 3D 명함을 "조건부 Go"로 되살렸다 — 온디바이스 합성·한글 텍스트 메시·2D 스냅샷은 전부 기준을 넘겼고, 유일한 미해결 항목인 첫 진입 지연(시뮬레이터 실측 9.42~11.62s)은 #1249 착수 전 실기기 재측정을 조건으로 건다(`docs/claude/business-card-3d-spike.md`). #1246이 베이스 USDZ 템플릿과 앵커 바인딩 규약을 정했고(`docs/claude/business-card-3d-anchor-contract.md`), #1247(회전)·#1248(온디바이스 합성)이 뒤따른다. 스파이크 하네스는 `#if DEBUG` 가드 아래에 있고(`Presentation/Sources/Spike/BusinessCard3DSpike.swift`), 템플릿 규약과 USDZ 에셋은 프로덕션 코드지만(`Presentation/Sources/Card3D/BusinessCardTemplate.swift` · `Presentation/Resources/BusinessCardTemplate.usdz`) 아직 어떤 화면에도 연결되지 않는다 — #1247·#1248 이 붙인다. **따라서 "UMCApp에 RealityKit 참조가 없다"는 더 이상 사실이 아니다** — `import RealityKit`이 `BusinessCardPresentation`에 이미 있다.

> **경계 정책 — 일정(Schedule) (#981 확정)**: 전용 Schedule Feature 모듈은 **신설하지 않는다.**
> 일정 도메인의 단일 소유자는 `HomeDomain`(모델·Repository/UseCase Protocol) + `HomeData`(`ScheduleV2Router`·`ScheduleRepository`·일정 DTO) + `HomePresentation`(일정 화면)이다.
> Activity 등 다른 Feature 는 `ScheduleDetailData`·`ScheduleLocation`·`ScheduleAttendancePolicy`·`ScheduleRepositoryProtocol` 을 **HomeDomain 에서 재사용**하며 자체 일정 모델을 다시 만들지 않는다.
> 단, 엔드포인트별 wire DTO 는 각 Feature Data 에 두는 것이 원칙이다 — 출석 응답의 `ScheduleLocationDTO`/`ScheduleAttendancePolicyDTO`(ActivityData)와 V2 일정 응답의 동명 DTO(HomeData)는 서로 다른 엔드포인트 계약이므로 의도적으로 분리돼 있고, 둘 다 같은 HomeDomain 모델로 매핑한다. (ActivityData → HomeData 링크는 HomeData 의 CoreML 리소스 번들까지 끌고 오므로 통합하지 않는다.)

### Feature 모듈 구조

각 Feature는 Clean Architecture에 따라 **3개 타겟**으로 분리됩니다.

| 타겟 | Product Type | Bundle ID 패턴 | Sources |
|------|-------------|----------------|---------|
| `{Name}Domain` | `.staticFramework` | `dev.umc.feature.{name}.domain` | `Domain/Sources/**` |
| `{Name}Data` | `.staticFramework` | `dev.umc.feature.{name}.data` | `Data/Sources/**` |
| `{Name}Presentation` | `.staticFramework` | `dev.umc.feature.{name}.presentation` | `Presentation/Sources/**` |

### ProjectDescriptionHelpers

보일러플레이트 제거를 위해 두 개의 헬퍼 함수를 사용합니다.

```swift
// Core 모듈 생성
coreProject(
    name: "CoreNetwork",
    bundleIdSuffix: "network",
    dependencies: [.target(name: "UMCFoundation"), .external(name: "Moya")]
)

// Feature 모듈 생성 (3개 타겟 자동 생성)
featureProject(
    name: "Auth",
    domainExtraDependencies: [],
    dataExtraDependencies: [],
    presentationExtraDependencies: []
)
```

두 헬퍼 모두 리소스 파라미터(`dataResources`/`presentationResources`)를 선택적으로 받는다.
`staticFramework`는 Compile Sources 산출물이 소비 타겟까지 전파되지 않으므로, 런타임에 필요한
자산은 별도 리소스 번들로 명시해야 한다 — 예: `HomeData`의 CoreML 모델(`dataResources`),
`BusinessCardPresentation`의 3D 명함 베이스 USDZ 템플릿(`presentationResources`, #1246).

### 외부 의존성

| 패키지 | 버전 | 사용처 |
|--------|------|--------|
| Moya | 15.0.3 | CoreNetwork |
| Kingfisher | 8.6.1 | CoreUIComponents |
| KakaoSDK (kakao-ios-sdk) | 2.27.0+ | CoreNetwork (`KakaoLoginManager`) |
| GoogleSignIn-iOS | 9.1.0+ | CoreNetwork (`GoogleLoginManager`) |

### 주요 설정

- **Tuist 버전**: `UMCApp/mise.toml` 고정 (`4.155.0`)
- **Deployment Target**: iOS 26.4 (`Project.swift` 기준, 전체 타겟 공통)
- **Product Type**: 모든 모듈 `.staticFramework`
- **Bundle ID**: Core → `dev.umc.core.*` / Feature → `dev.umc.feature.*.*`
- **Workspace**: glob(`Core/*`, `Features/*`) + `UMCAppWidget`, `UMCWatchApp` 명시 포함
