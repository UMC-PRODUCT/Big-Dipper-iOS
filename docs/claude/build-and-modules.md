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

> **경계 정책 — BusinessCard**: MyPage·Home·Community·Activity·Auth 등 명함을 노출하는 Feature는 `BusinessCardPresentation`만 링크해 카드 UI(`BusinessCardFaceView` 등)를 재사용하며, 카드 화면을 자체 구현하지 않는다. 렌더링은 2D SwiftUI로 확정 — 초기 구상이던 RealityKit(3D) 렌더링은 폐기됐고(#1196에서 ARKit·RealityKit 링크 해제) UMCApp에 RealityKit 참조가 없다.

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

### 공유 Keychain Access Group

iOS 앱과 watchOS 앱은 로그인 토큰용 공유 그룹 `$(AppIdentifierPrefix)com.umc.product.shared` 를
`keychain-access-groups` entitlement 의 **첫 항목**으로 선언합니다. 팀 ID(`8B8B4462NV`)를 문자열로
박지 않고 `$(AppIdentifierPrefix)` 를 쓰는 것이 레포 관례입니다
(`UMCApp/Core/Network/Tests/CoreNetworkTests.entitlements` 동일).

| 타겟 | entitlements 파일 | 배선 위치 |
|------|------------------|----------|
| iOS 앱 | `UMCApp/UMCApp.entitlements:27-31` | `UMCApp/Project.swift:85` |
| watchOS 앱 | `UMCApp/UMCWatchApp/UMCWatchApp.entitlements:7-11` | `UMCApp/UMCWatchApp/Project.swift:7` |

- **배열 순서가 계약이다.** `kSecAttrAccessGroup` 을 지정하지 않은 `SecItemAdd` 는 배열 **첫 항목**에
  저장한다. `UMCApp/Core/Network/Sources/Auth/KeychainTokenStore.swift` 는 저장(104-110행) ·
  조회(120-126행) · 삭제(141-145행) 쿼리 어디에도 access group 을 지정하지 않으므로 이 기본값 규칙에
  전적으로 의존한다. 그래서 공유 그룹이 첫 번째다.
- **두 번째 항목(각 타겟 자기 App ID 그룹)은 안전장치다.** 검색·삭제는 access group 미지정 시 앱이 가진
  모든 그룹을 대상으로 하므로, 기존 배포판이 기본 그룹(`$(AppIdentifierPrefix)com.umc.product`)에 저장해 둔
  토큰이 계속 읽힌다. 이 줄을 빼면 업데이트 즉시 전 사용자 강제 로그아웃이다.
- **워치는 배선까지 확인한다.** `watchAppProject(entitlements: .file(path: "UMCWatchApp.entitlements"))` 로
  인자를 넘겨야 실제로 적용된다. 파일만 만들고 인자를 안 넘기면 무효다 — #1147 유실이 정확히 이 형태였다.
- **watchOS 는 keychain 을 공유하지 않는다.** Apple Watch 는 자체 keychain 을 가진 별개 기기라 access
  group 을 맞춰도 워치가 iPhone 의 항목을 읽지 못한다. access group 은 동일 기기 내 동일 팀 서명 타겟
  (앱·확장) 간 공유 메커니즘이다. 워치 토큰은 WatchConnectivity 로 iPhone→Watch 전송 후 워치 자체
  keychain 에 저장하는 경로이며 #1210/#1211 범위다. 또한 `KeychainTokenStore` 는
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`(109행)라 iCloud Keychain 동기화 대상도 아니다.
- **서명 주의**: 두 App ID(`com.umc.product` · `com.umc.product.watchkitapp`)에 Keychain Sharing
  capability 가 없으면 실기기/아카이브 서명 단계에서 실패하고, 런타임 증상은 `SecItemAdd` 의
  `errSecMissingEntitlement(-34018)` 다.

> **유실 이력**: PR #627(`744ad80b`)이 공유 그룹(`$(AppIdentifierPrefix)dev.umc.shared`)을 추가했으나,
> #1147(`a68f93c2`) 번들 ID 정렬 커밋이 "미사용 keychain-access-groups 제거" 사유로 iOS·watch 양쪽에서
> 걷어냈다(워치 entitlements 는 파일째 삭제). 이미 **두 번 유실된** entitlement 다 — "미사용"으로 보여도
> 제거하지 않는다.
