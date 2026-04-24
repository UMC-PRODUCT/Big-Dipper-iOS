# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**UMC(University MakeUs Challenge) 동아리 운영 관리 앱**
SwiftUI + iOS 26.2+ 기반 (Liquid Glass 지원)

- **App Statement**: "Focus on Growth, We Handle the Ops"
- **목적**: 동아리 운영 도구 일원화 (디스코드/구글시트/노션 분산 문제 해결)
- **주요 모듈**: 인증/온보딩, 홈 대시보드, 공지사항, 운영/학교 관리, 스터디/활동, 커뮤니티, 마이페이지
- **Killer Features**: The Ping (공지 수신 확인), Mobile-First Admin, GPS 기반 스마트 출석
- **현재 버전**: 1.7.0

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
│   ├── BusinessCard/              # 전자명함 (3D 렌더링 캡슐화 경계 모듈)
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

> **경계 정책 — BusinessCard**: `Model3D`/`RealityView` 등 RealityKit 렌더링은 `BusinessCardPresentation` 내부에만 캡슐화한다. MyPage·Home·Community·Activity·Auth 등 명함을 노출하는 Feature는 `BusinessCardPresentation`만 링크하며, RealityKit을 직접 링크하지 않는다.

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

### 주요 설정

- **Tuist 버전**: `UMCApp/mise.toml` 고정 (`4.155.0`)
- **Deployment Target**: iOS 26.3 (`Project.swift` 기준, 전체 타겟 공통)
- **Product Type**: 모든 모듈 `.staticFramework`
- **Bundle ID**: Core → `dev.umc.core.*` / Feature → `dev.umc.feature.*.*`
- **Workspace**: glob(`Core/*`, `Features/*`) + `UMCAppWidget`, `UMCWatchApp` 명시 포함

---

## Architecture

**Feature-Based Modular + Clean Architecture + Observation**

### 데이터 흐름

```
View ←→ ViewModel(@Observable) → UseCase(Protocol) → Repository → DataSource
                                    ↑
                   DIContainer가 Protocol 구현체 주입
```

### Feature 폴더 구조

```
Features/{Feature}/
├── Presentation/
│   ├── Views/           # SwiftUI View
│   ├── ViewModels/      # @Observable ViewModel
│   ├── Components/      # Feature 전용 컴포넌트
│   └── Router/          # Feature Router
├── Domain/
│   ├── UseCases/        # Protocol + Implementations/
│   ├── Models/          # Entity
│   └── Interfaces/      # Repository Protocol
└── Data/
    ├── Repositories/    # Repository 구현체
    └── DataSources/     # API, Local Storage
```

### 계층 원칙

- **Presentation → Domain**: View/ViewModel은 UseCase Protocol에만 의존
- **Domain → Data**: UseCase는 Repository Protocol 사용, 구현체 모름
- **Protocol 기반 주입**: DIContainer가 런타임에 구현체 결정

### SOLID 원칙

| 원칙 | 적용 |
|------|------|
| **S**ingle Responsibility | View(UI 렌더링), ViewModel(상태 관리), UseCase(비즈니스 로직), Repository(데이터 접근) 분리 |
| **O**pen/Closed | Protocol 기반 설계로 기존 코드 수정 없이 새 구현체 추가 가능 |
| **L**iskov Substitution | Protocol 구현체는 언제든 교체 가능 (Mock, Real, Stub) |
| **I**nterface Segregation | 큰 Protocol보다 작고 명확한 Protocol 여러 개로 분리 |
| **D**ependency Inversion | 상위 모듈(UseCase)이 하위 모듈(Repository) 구현체가 아닌 Protocol에 의존 |

```swift
// DIP 예시: UseCase는 Protocol에만 의존
protocol UserRepositoryProtocol {
    func fetchUser(id: String) async throws -> User
}

final class FetchUserUseCase {
    private let repository: UserRepositoryProtocol  // 구현체가 아닌 Protocol

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }
}
```

### DIContainer

```swift
// 등록
container.register(UserRepositoryProtocol.self) { UserRepository() }
container.register(LoginUseCaseProtocol.self) {
    LoginUseCase(repository: container.resolve(UserRepositoryProtocol.self))
}

// 사용
let useCase = container.resolve(LoginUseCaseProtocol.self)
```

- `@Observable` 기반으로 SwiftUI Environment 주입 가능
- `resolve()` 호출 시 캐싱 (싱글톤처럼 동작)
- `resetCache()`: 로그아웃 시 전체 초기화

### Router (Hierarchical Router Pattern)

- **AppRouter**: 모듈 간 전환, Deep Link 처리 (조율자)
- **Feature Router**: 각 Feature 내부 화면 전환
- Tab별 독립 `NavigationStack`으로 상태 보존

## Observation 패턴

### ViewModel 규칙

```swift
@Observable
final class ChallengerAttendanceViewModel {
    private var container: DIContainer
    private var useCase: ChallengerAttendanceUseCaseProtocol

    // Loadable로 비동기 상태 관리
    private(set) var attendanceState: Loadable<Attendance> = .idle

    // Action 메서드
    @MainActor
    func attendanceBtnTapped(userId: UserID) async {
        attendanceState = .loading
        do {
            let result = try await useCase.requestGPSAttendance(...)
            attendanceState = .loaded(result)
        } catch let error as DomainError {
            attendanceState = .failed(.domain(error))  // 인라인 에러
        } catch {
            errorHandler.handle(error, context: ...)   // Alert 에러
        }
    }
}
```

**필수 규칙:**
- `@Observable` 매크로 사용 (**NOT** `@StateObject`, `@ObservedObject`, `@Published`)
- 예외: 앱 생명주기 연결 전역 상태 관리자 (`AppFlowViewModel`)

### View 규칙

```swift
struct ChallengerAttendanceView: View {
    @State private var viewModel: ChallengerAttendanceViewModel

    init(container: DIContainer, ...) {
        _viewModel = State(initialValue: ChallengerAttendanceViewModel(
            container: container,
            ...
        ))
    }

    var body: some View { ... }
}
```

- `@State private var viewModel` 패턴으로 소유권 명시
- Action 기반 단방향 데이터 흐름

## 에러 처리 시스템

### Loadable (로컬/인라인 에러)

```swift
enum Loadable<T: Equatable> {
    case idle       // 초기 상태
    case loading    // 로딩 중
    case loaded(T)  // 성공
    case failed(AppError)  // 실패 (인라인 표시)
}

// View에서 사용
switch viewModel.attendanceState {
case .idle: Color.clear.task { await viewModel.fetch() }
case .loading: ProgressView()
case .loaded(let data): ContentView(data: data)
case .failed(let error): ErrorView(error: error, retry: ...)
}
```

### ErrorHandler (전역 Alert 에러)

```swift
// 네트워크 오류, 세션 만료 등 → Alert
errorHandler.handle(error, context: ErrorContext(
    feature: "Activity",
    action: "attendanceBtnTapped",
    retryAction: { [weak self] in await self?.retry() }
))
```

**에러 처리 선택 기준:**
- **ErrorHandler**: 작업 흐름 중단, 즉각적 사용자 액션 필요 (세션 만료, 권한 요청, 네트워크 오류)
- **Loadable**: 화면 내 상태 표시 (리스트 로딩 실패, 도메인 에러, 검증 실패)

### AlertPrompt (확인/취소 다이얼로그)

```swift
// ViewModel
@Observable
final class SomeViewModel {
    var alertPrompt: AlertPrompt?

    func deleteButtonTapped() {
        alertPrompt = AlertPrompt(
            title: "삭제 확인",
            message: "정말 삭제하시겠습니까?",
            positiveBtnTitle: "삭제",
            isPositiveBtnDestructive: true,
            positiveBtnAction: { [weak self] in
                self?.delete()
            },
            negativeBtnTitle: "취소"
        )
    }
}

// View
.alertPrompt(item: $viewModel.alertPrompt)
```

**AlertPrompt 사용 기준:**
- 파괴적 작업 전 확인 (삭제, 초기화 등)
- 사용자 선택이 필요한 분기점

## 디자인 시스템

토큰 정의: `DefaultConstant.swift`, `DefaultSpacing.swift`

### 레이아웃 상수 (`DefaultConstant`)

| 상수 | 값 | 용도 |
|------|----|------|
| `defaultSafeHorizon` | 16 | 좌우 기본 여백 |
| `defaultSafeTop` | 20 | 상단 기본 여백 |
| `defaultSafeBottom` | 56 | 하단 탭바 safe area |
| `defaultCornerRadius` | 30 | 기본 모서리 반경 |
| `concentricRadius` | 40 | ConcentricRectangle 최소 반경 |
| `defaultCapsuleSpacing` | 28 | 캡슐형 요소 여백 |

### Typography (`AppFont`)

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

### Shape 패턴 (권장)

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

### Glass Effect 선택

| Variant | 용도 |
|---------|------|
| `.regular` | 일반 카드, 폼 |
| `.regular.interactive()` | 탭 가능 요소 |
| `.clear` | 미디어/색상 배경 위 |
| `.glassProminent` (ButtonStyle) | Primary 버튼 |
| `.glass` (ButtonStyle) | Secondary 버튼 |

### 공용 UI 컴포넌트 (`Core/Common/UIComponents/`)

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

## Swift 코딩 스타일

- **들여쓰기**: 4 spaces (탭 금지)
- **줄 길이**: 최대 99자
- **접근 제어자**: 외부 불필요 상태는 `private` 필수
- **상수**: View 내부 전용은 `fileprivate enum Constants`

### MARK 구분

```swift
// MARK: - Property
// MARK: - Body
// MARK: - Function
```

## Git Workflow

Git Flow + **연속 브랜치 파생** 지원

### 브랜치 전략

- **연속 브랜치**: feature에서 다음 feature 파생 가능 (티켓 단위 분리)
- **PR 대기 중 작업**: 승인 대기 중 이전 브랜치에서 다음 브랜치 생성 가능
- **동기화**: develop에서 merge 대신 `fetch + rebase` 사용

### 배포 브랜치 전략

- **TestFlight 배포**: `testFlight/{번호}` 브랜치 생성 → `testFlight`으로 PR 머지
- **Release 배포**: `release/{번호}` 브랜치 생성 → `release`로 PR 머지
- 배포 브랜치는 `develop`에서 분기하여 번호를 순차적으로 매김
- 직접 푸시 금지, 반드시 PR을 통해 머지

### 커밋 형식

`type: 작업 내용`

커밋 메시지는 제목 한 줄 + 빈 줄 + 변경사항 bullet list 형식으로 작성.

| Type | 용도 |
|------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` | 리팩토링 |
| `docs` | 문서 |
| `chore` | 기타 |
| `test` | 테스트 |
| `design` | UI/디자인 시스템 |

**커밋 메시지에 `Co-Authored-By` 라인을 절대 추가하지 마세요.**

### PR 규칙

- 최소 1인 Approve 필수
- main/develop 직접 푸시 금지
- Squash and Merge 사용
- **배포 PR 예외**: `testFlight`, `release` 브랜치로의 PR은 **Merge Commit** 사용 (커밋 히스토리 동기화를 위해)

## 프로젝트 구조

```
AppProduct/AppProduct/
├── Core/
│   ├── Alert/              # AlertPrompt 등 확인 다이얼로그
│   ├── Common/
│   │   ├── DesignSystem/   # 디자인 토큰, 스타일
│   │   ├── Enum/           # DefaultConstant, DefaultSpacing 등
│   │   ├── Error/          # Loadable, ErrorHandler, AppError 등
│   │   └── UIComponents/   # 공용 UI 컴포넌트
│   ├── DIContainer/        # 의존성 주입 컨테이너
│   ├── Manager/            # 인증, 위치 등 시스템 매니저
│   ├── Mock/               # 테스트용 Mock View (개발 전용)
│   ├── Navigation/         # 네비게이션 라우팅
│   ├── NetworkAdapter/     # Moya 기반 네트워크 클라이언트
│   └── Secret/             # API 키 등 민감 정보
├── Utilities/
│   ├── Extensions/         # Swift/SwiftUI 확장
│   ├── Keychain/           # 키체인 유틸리티
│   ├── Modifier/           # 커스텀 ViewModifier
│   ├── RemoteImage/        # 원격 이미지 로딩
│   ├── Shadow/             # 그림자 유틸리티
│   └── ToolBar/            # 툴바 헬퍼
└── Features/
    ├── Activity/           # 출석, 스터디 관리
    ├── Auth/               # 로그인, 회원가입
    ├── Community/          # 커뮤니티, 명예의전당
    ├── Home/               # 홈 대시보드, 일정 관리
    ├── MyPage/             # 마이페이지, 프로필
    ├── Notice/             # 공지사항
    ├── Splash/             # 스플래시 화면
    └── Tab/                # 탭 네비게이션
```
