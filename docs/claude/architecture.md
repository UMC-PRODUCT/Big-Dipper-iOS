# Architecture + Observation + 에러 처리

> 아키텍처 계층, ViewModel/View 패턴, 에러 처리 시스템에 대한 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

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
