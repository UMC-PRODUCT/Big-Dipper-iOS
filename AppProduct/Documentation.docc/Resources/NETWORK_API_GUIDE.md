# Network API 사용 가이드

UMC 프로젝트의 네트워크 레이어 사용 방법을 단계별로 설명합니다.

- 작성자: 제옹(euijjang97)

## 목차

1. [아키텍처 개요](#아키텍처-개요)
2. [새로운 API 추가하기](#새로운-api-추가하기)
3. [완전한 예제: User API](#완전한-예제-user-api)
4. [에러 처리](#에러-처리)
5. [테스트 작성](#테스트-작성)

---

## 아키텍처 개요

### 데이터 흐름

```
View
  ↓ (Action)
ViewModel (@Observable)
  ↓ (UseCase Protocol 호출)
UseCase (비즈니스 로직)
  ↓ (Repository Protocol 호출)
Repository (데이터 접근)
  ↓ (MoyaNetworkAdapter)
NetworkClient (JWT 인증 + 토큰 갱신)
  ↓
Server
```

### 계층별 책임

| 계층 | 책임 | 의존성 |
|------|------|--------|
| **View** | UI 렌더링, 사용자 이벤트 처리 | ViewModel |
| **ViewModel** | 상태 관리, View 로직 | UseCase Protocol |
| **UseCase** | 비즈니스 로직, 도메인 규칙 | Repository Protocol |
| **Repository** | 데이터 소스 접근, DTO ↔ Entity 변환 | MoyaNetworkAdapter |
| **NetworkClient** | JWT 인증, 토큰 갱신, 네트워크 요청 | URLSession |

### 핵심 원칙

- **Protocol 기반 의존성**: 구현체가 아닌 Protocol에 의존
- **의존성 주입**: DIContainer가 런타임에 구현체 주입
- **단방향 데이터 흐름**: View → ViewModel → UseCase → Repository

---

## 새로운 API 추가하기

### Step 1: Moya TargetType 정의

**위치**: `Features/{Feature}/Data/DataSources/`

```swift
// Features/User/Data/DataSources/UserAPI.swift
import Foundation
import Moya

enum UserAPI {
    case getMe
    case updateProfile(name: String, bio: String)
    case deleteAccount
}

extension UserAPI: BaseTargetType {
    var baseURL: URL {
        URL(string: "https://api.umc.com")!
    }

    var path: String {
        switch self {
        case .getMe:
            return "/users/me"
        case .updateProfile:
            return "/users/me"
        case .deleteAccount:
            return "/users/me"
        }
    }

    var method: Moya.Method {
        switch self {
        case .getMe:
            return .get
        case .updateProfile:
            return .put
        case .deleteAccount:
            return .delete
        }
    }

    var task: Task {
        switch self {
        case .getMe:
            return .requestPlain

        case .updateProfile(let name, let bio):
            let parameters: [String: Any] = [
                "name": name,
                "bio": bio
            ]
            return .requestParameters(
                parameters: parameters,
                encoding: JSONEncoding.default
            )

        case .deleteAccount:
            return .requestPlain
        }
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}
```

### Step 2: DTO (Data Transfer Object) 정의

**위치**: `Features/{Feature}/Data/DTOs/`

```swift
// Features/User/Data/DTOs/UserDTO.swift
import Foundation

/// 서버 응답 DTO
struct UserDTO: Codable {
    let id: Int
    let name: String
    let email: String
    let bio: String?
    let profileImageUrl: String?
    let createdAt: String
}

extension UserDTO {
    /// DTO → Domain Entity 변환
    func toDomain() -> User {
        User(
            id: UserID(value: id),
            name: name,
            email: email,
            bio: bio,
            profileImageUrl: profileImageUrl.flatMap { URL(string: $0) },
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}
```

### Step 3: Repository Protocol 정의

**위치**: `Features/{Feature}/Domain/Interfaces/`

```swift
// Features/User/Domain/Interfaces/UserRepositoryProtocol.swift
import Foundation

/// User 데이터 접근을 추상화하는 Repository Protocol
protocol UserRepositoryProtocol {
    /// 내 프로필 조회
    func getMe() async throws -> User

    /// 프로필 수정
    func updateProfile(name: String, bio: String) async throws -> User

    /// 회원 탈퇴
    func deleteAccount() async throws
}
```

### Step 4: Repository 구현

**위치**: `Features/{Feature}/Data/Repositories/`

```swift
// Features/User/Data/Repositories/UserRepository.swift
import Foundation

struct UserRepository: UserRepositoryProtocol {
    // MARK: - Property

    private let adapter: MoyaNetworkAdapter

    // MARK: - Initializer

    init(adapter: MoyaNetworkAdapter) {
        self.adapter = adapter
    }

    // MARK: - UserRepositoryProtocol

    func getMe() async throws -> User {
        // 1. API 호출
        let response = try await adapter.request(UserAPI.getMe)

        // 2. APIResponse 파싱
        let apiResponse = try JSONDecoder().decode(
            APIResponse<UserDTO>.self,
            from: response.data
        )

        // 3. 성공 여부 확인 + result 추출 (unwrap)
        let userDTO = try apiResponse.unwrap()

        // 4. DTO → Domain Entity 변환
        return userDTO.toDomain()
    }

    func updateProfile(name: String, bio: String) async throws -> User {
        let response = try await adapter.request(
            UserAPI.updateProfile(name: name, bio: bio)
        )

        let apiResponse = try JSONDecoder().decode(
            APIResponse<UserDTO>.self,
            from: response.data
        )
        let userDTO = try apiResponse.unwrap()

        return userDTO.toDomain()
    }

    func deleteAccount() async throws {
        let response = try await adapter.request(UserAPI.deleteAccount)

        // 결과 없는 API는 EmptyResult 사용
        let apiResponse = try JSONDecoder().decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }
}

// MARK: - RepositoryError

/// Repository 계층에서 발생하는 에러
/// - serverError: 서버에서 isSuccess: false 응답 시
/// - decodingError: JSON 디코딩 실패 시
enum RepositoryError: Error, LocalizedError, Sendable, Equatable {
    /// 서버에서 실패 응답 반환 (isSuccess: false)
    case serverError(code: String?, message: String?)

    /// 응답 데이터 디코딩 실패
    case decodingError(detail: String?)

    var errorDescription: String? {
        switch self {
        case .serverError(_, let message):
            return message ?? "서버 오류가 발생했습니다"
        case .decodingError(let detail):
            return "데이터 파싱 실패: \(detail ?? "알 수 없는 오류")"
        }
    }
}
```

### Step 5: UseCase Protocol 정의

**위치**: `Features/{Feature}/Domain/UseCases/`

```swift
// Features/User/Domain/UseCases/GetUserProfileUseCaseProtocol.swift
import Foundation

/// 사용자 프로필 조회 UseCase Protocol
protocol GetUserProfileUseCaseProtocol {
    /// 내 프로필 조회
    func execute() async throws -> User
}
```

### Step 6: UseCase 구현

**위치**: `Features/{Feature}/Domain/UseCases/Implementations/`

```swift
// Features/User/Domain/UseCases/Implementations/GetUserProfileUseCase.swift
import Foundation

final class GetUserProfileUseCase: GetUserProfileUseCaseProtocol {
    // MARK: - Property

    private let repository: UserRepositoryProtocol

    // MARK: - Initializer

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - GetUserProfileUseCaseProtocol

    func execute() async throws -> User {
        // 비즈니스 로직이 필요하다면 여기에 추가
        // 예: 캐싱, 검증, 데이터 가공 등
        try await repository.getMe()
    }
}
```

### Step 7: DIContainer에 등록

**위치**: `Core/DIContainer/DIContainer.swift`

```swift
// DIContainer.swift
import Foundation

@Observable
final class DIContainer {
    // MARK: - Singleton

    static let shared = DIContainer()

    // MARK: - Network

    private(set) lazy var networkClient: NetworkClient = {
        AuthSystemFactory.makeNetworkClient(
            baseURL: URL(string: "https://api.umc.com")!
        )
    }()

    private(set) lazy var moyaAdapter: MoyaNetworkAdapter = {
        MoyaNetworkAdapter(
            networkClient: networkClient,
            baseURL: URL(string: "https://api.umc.com")!
        )
    }()

    // MARK: - Repositories

    private(set) lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(adapter: moyaAdapter)
    }()

    // MARK: - UseCases

    func getUserProfileUseCase() -> GetUserProfileUseCaseProtocol {
        GetUserProfileUseCase(repository: userRepository)
    }

    func updateUserProfileUseCase() -> UpdateUserProfileUseCaseProtocol {
        UpdateUserProfileUseCase(repository: userRepository)
    }

    private init() {}
}
```

### Step 8: ViewModel 작성

**위치**: `Features/{Feature}/Presentation/ViewModels/`

```swift
// Features/User/Presentation/ViewModels/UserProfileViewModel.swift
import Foundation

@Observable
final class UserProfileViewModel {
    // MARK: - Property

    private let getUserProfileUseCase: GetUserProfileUseCaseProtocol
    private let updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol

    // Loadable로 비동기 상태 관리
    private(set) var userState: Loadable<User> = .idle

    // MARK: - Initializer

    init(
        getUserProfileUseCase: GetUserProfileUseCaseProtocol,
        updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol
    ) {
        self.getUserProfileUseCase = getUserProfileUseCase
        self.updateUserProfileUseCase = updateUserProfileUseCase
    }

    // MARK: - Action

    @MainActor
    func loadProfile() async {
        userState = .loading

        do {
            let user = try await getUserProfileUseCase.execute()
            userState = .loaded(user)
        } catch let error as DomainError {
            // 도메인 에러 → 인라인 표시 (Loadable)
            userState = .failed(.domain(error))
        } catch let error as NetworkError {
            // 네트워크 에러 → AppError.network로 래핑
            userState = .failed(.network(error))
        } catch {
            // 기타 에러 → unknown
            userState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    @MainActor
    func updateProfile(name: String, bio: String) async {
        do {
            let updatedUser = try await updateUserProfileUseCase.execute(
                name: name,
                bio: bio
            )
            userState = .loaded(updatedUser)
        } catch let error as NetworkError {
            userState = .failed(.network(error))
        } catch {
            userState = .failed(.unknown(message: error.localizedDescription))
        }
    }
}
```

### Step 9: View 작성

**위치**: `Features/{Feature}/Presentation/Views/`

```swift
// Features/User/Presentation/Views/UserProfileView.swift
import SwiftUI

struct UserProfileView: View {
    // MARK: - Property

    @State private var viewModel: UserProfileViewModel
    @Environment(\.di) private var di

    // MARK: - Initializer

    init(container: DIContainer) {
        _viewModel = State(initialValue: UserProfileViewModel(
            getUserProfileUseCase: container.getUserProfileUseCase(),
            updateUserProfileUseCase: container.updateUserProfileUseCase()
        ))
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch viewModel.userState {
            case .idle:
                Color.clear
                    .task {
                        await viewModel.loadProfile()
                    }

            case .loading:
                LoadingView(.home(.seasonLoading))

            case .loaded(let user):
                UserProfileContentView(user: user) {
                    await viewModel.updateProfile(
                        name: "New Name",
                        bio: "New Bio"
                    )
                }

            case .failed(let error):
                ErrorView(error: error) {
                    await viewModel.loadProfile()
                }
            }
        }
        .navigationTitle("프로필")
    }
}

// MARK: - Content View

struct UserProfileContentView: View {
    let user: User
    let onUpdate: () async -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(user.name)
                .font(.title)

            Text(user.email)
                .font(.subheadline)

            if let bio = user.bio {
                Text(bio)
                    .font(.body)
            }

            Button("프로필 수정") {
                Task {
                    await onUpdate()
                }
            }
        }
        .padding()
    }
}
```

---

## 완전한 예제: User API

위의 모든 단계를 따라 구현한 전체 예제는 다음 파일들을 참고하세요:

```
Features/User/
├── Data/
│   ├── DataSources/
│   │   └── UserAPI.swift
│   ├── DTOs/
│   │   └── UserDTO.swift
│   └── Repositories/
│       └── UserRepository.swift
├── Domain/
│   ├── Interfaces/
│   │   └── UserRepositoryProtocol.swift
│   ├── Models/
│   │   └── User.swift
│   └── UseCases/
│       ├── GetUserProfileUseCaseProtocol.swift
│       ├── UpdateUserProfileUseCaseProtocol.swift
│       └── Implementations/
│           ├── GetUserProfileUseCase.swift
│           └── UpdateUserProfileUseCase.swift
└── Presentation/
    ├── ViewModels/
    │   └── UserProfileViewModel.swift
    └── Views/
        └── UserProfileView.swift
```

---

## 에러 처리

### Loadable 패턴 (인라인 에러)

화면 내에서 에러를 표시할 때 사용합니다.

```swift
@Observable
final class SomeViewModel {
    private(set) var dataState: Loadable<Data> = .idle

    @MainActor
    func fetch() async {
        dataState = .loading

        do {
            let data = try await useCase.execute()
            dataState = .loaded(data)
        } catch let error as DomainError {
            // 도메인 에러 → 화면 내 표시 (인라인)
            dataState = .failed(.domain(error))
        } catch let error as NetworkError {
            // 네트워크 에러 → 화면 내 표시 (인라인)
            dataState = .failed(.network(error))
        } catch {
            // 기타 에러
            dataState = .failed(.unknown(message: error.localizedDescription))
        }
    }
}

// View
switch viewModel.dataState {
case .idle: Color.clear
case .loading: ProgressView()
case .loaded(let data): ContentView(data: data)
case .failed(let error): ErrorView(error: error, retry: { await viewModel.fetch() })
}
```

### ErrorHandler (전역 Alert 에러)

작업 흐름을 중단하고 즉각적인 사용자 액션이 필요한 경우 사용합니다.

```swift
@Observable
final class SomeViewModel {
    private let errorHandler: ErrorHandler

    @MainActor
    func criticalAction() async {
        do {
            try await useCase.execute()
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "User",
                action: "criticalAction",
                retryAction: { [weak self] in
                    await self?.criticalAction()
                }
            ))
        }
    }
}
```

### 네트워크 에러 종류

NetworkClient(Actor 기반)에서 발생하는 에러 타입입니다.

```swift
// NetworkError - Actor 기반 네트워크 클라이언트 에러
enum NetworkError: Error, Sendable, Equatable {
    case unauthorized                         // 인증 토큰 없음 (401)
    case tokenRefreshFailed(reason: String?)  // 토큰 갱신 실패
    case noRefreshToken                       // 리프레시 토큰 없음
    case requestFailed(statusCode: Int, data: Data?)  // API 요청 실패
    case invalidResponse                      // 잘못된 응답
    case maxRetryExceeded                     // 재시도 횟수 초과
    case noNetwork                            // 네트워크 연결 없음
    case timeout                              // 요청 시간 초과
}

// 에러 처리 예시
do {
    let data = try await networkClient.request(urlRequest)
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // 로그인 필요
        navigateToLogin()

    case .tokenRefreshFailed(let reason):
        // 토큰 갱신 실패 → 재로그인
        print("갱신 실패 원인: \(reason ?? "알 수 없음")")
        navigateToLogin()

    case .noRefreshToken:
        // 리프레시 토큰 없음
        navigateToLogin()

    case .requestFailed(let statusCode, _):
        // 서버 에러
        if statusCode == 404 {
            print("리소스 없음")
        } else if statusCode >= 500 {
            print("서버 에러")
        }

    case .invalidResponse:
        // 네트워크 연결 문제
        print("네트워크 연결 확인")

    case .maxRetryExceeded:
        // 재시도 횟수 초과
        print("재로그인 필요")

    case .noNetwork:
        // 네트워크 연결 없음 (URLError.notConnectedToInternet)
        print("인터넷 연결을 확인해주세요")

    case .timeout:
        // 요청 시간 초과 (URLError.timedOut)
        print("서버 응답이 늦어지고 있어요")
    }
}
```

#### 에러 타입 계층 구조

프로젝트는 계층별로 명확히 분리된 에러 타입을 사용합니다:

| 에러 타입 | 발생 계층 | 용도 |
|----------|---------|------|
| **NetworkError** | NetworkClient (Actor 기반) | HTTP 통신, JWT 인증, 토큰 갱신, 네트워크 연결 |
| **RepositoryError** | Repository | 서버 비즈니스 에러 (isSuccess: false), 디코딩 실패 |
| **DomainError** | UseCase/Domain | 비즈니스 규칙 위반 |

모든 에러는 `AppError`로 통합됩니다:
```swift
enum AppError: Error, LocalizedError, Equatable {
    case network(NetworkError)      // 네트워크 계층 에러
    case repository(RepositoryError) // Repository 계층 에러
    case validation(ValidationError) // 입력 유효성 검증
    case auth(AuthError)            // 인증 관련
    case domain(DomainError)        // 도메인 비즈니스 로직
    case unknown(message: String)   // 알 수 없는 에러
}
```

> **Note**: 이전에 사용하던 `APIError`는 `NetworkError`와 `RepositoryError`로 통합되었습니다.
> - HTTP 통신 에러 → `NetworkError`
> - 서버 응답 에러 (isSuccess: false) → `RepositoryError.serverError`
> - 디코딩 에러 → `RepositoryError.decodingError`

---

## 테스트 작성

> **Note**: Swift Testing 프레임워크를 사용합니다 (Xcode 15+, Swift 5.9+)
>
> XCTest 방식도 계속 지원되지만, Swift Testing이 더 현대적이고 타입 안전합니다.

### Repository 테스트

#### Swift Testing (권장)

```swift
import Testing
@testable import AppProduct

@Suite("User Repository Tests")
struct UserRepositoryTests {
    let mockAdapter: MockMoyaNetworkAdapter
    let sut: UserRepository

    init() {
        mockAdapter = MockMoyaNetworkAdapter()
        sut = UserRepository(adapter: mockAdapter)
    }

    @Test("사용자 프로필 조회 성공")
    func getMeSuccess() async throws {
        // Given
        let expectedUser = User(
            id: UserID(value: 1),
            name: "Test User",
            email: "test@example.com",
            bio: "Test Bio",
            profileImageUrl: nil,
            createdAt: Date()
        )
        mockAdapter.mockResponse = createMockResponse(user: expectedUser)

        // When
        let user = try await sut.getMe()

        // Then
        #expect(user.name == expectedUser.name)
        #expect(user.email == expectedUser.email)
        #expect(user.bio == expectedUser.bio)
    }

    @Test("네트워크 에러 시 예외 발생")
    func getMeNetworkError() async throws {
        // Given
        mockAdapter.shouldFail = true

        // When & Then
        await #expect {
            try await sut.getMe()
        } throws: { error in
            error is NetworkError
        }
    }

    @Test("서버 에러 응답 처리", arguments: [400, 404, 500, 503])
    func getMeServerError(statusCode: Int) async throws {
        // Given
        mockAdapter.mockStatusCode = statusCode

        // When & Then
        await #expect {
            try await sut.getMe()
        } throws: { error in
            guard let repoError = error as? RepositoryError,
                  case .serverError = repoError else {
                return false
            }
            return true
        }
    }
}
```

#### XCTest (레거시)

<details>
<summary>XCTest 방식 보기</summary>

```swift
import XCTest
@testable import AppProduct

final class UserRepositoryTests: XCTestCase {
    var sut: UserRepository!
    var mockAdapter: MockMoyaNetworkAdapter!

    override func setUp() {
        super.setUp()
        mockAdapter = MockMoyaNetworkAdapter()
        sut = UserRepository(adapter: mockAdapter)
    }

    func test_getMe_성공() async throws {
        // Given
        let expectedUser = User(
            id: UserID(value: 1),
            name: "Test User",
            email: "test@example.com",
            bio: "Test Bio",
            profileImageUrl: nil,
            createdAt: Date()
        )
        mockAdapter.mockResponse = createMockResponse(user: expectedUser)

        // When
        let user = try await sut.getMe()

        // Then
        XCTAssertEqual(user.name, expectedUser.name)
        XCTAssertEqual(user.email, expectedUser.email)
    }
}
```

</details>

---

### UseCase 테스트

#### Swift Testing (권장)

```swift
import Testing
@testable import AppProduct

@Suite("Get User Profile UseCase Tests")
struct GetUserProfileUseCaseTests {
    let mockRepository: MockUserRepository
    let sut: GetUserProfileUseCase

    init() {
        mockRepository = MockUserRepository()
        sut = GetUserProfileUseCase(repository: mockRepository)
    }

    @Test("프로필 조회 성공")
    func executeSuccess() async throws {
        // Given
        let expectedUser = User(
            id: UserID(value: 1),
            name: "Test User",
            email: "test@example.com",
            bio: "iOS Developer",
            profileImageUrl: URL(string: "https://example.com/avatar.jpg"),
            createdAt: Date()
        )
        mockRepository.mockUser = expectedUser

        // When
        let user = try await sut.execute()

        // Then
        #expect(user.name == expectedUser.name)
        #expect(user.email == expectedUser.email)
        #expect(user.bio == "iOS Developer")
    }

    @Test("Repository 에러 전파")
    func executeRepositoryError() async throws {
        // Given
        mockRepository.shouldFail = true

        // When & Then
        await #expect {
            try await sut.execute()
        } throws: { error in
            error is RepositoryError
        }
    }
}
```

#### XCTest (레거시)

<details>
<summary>XCTest 방식 보기</summary>

```swift
final class GetUserProfileUseCaseTests: XCTestCase {
    var sut: GetUserProfileUseCase!
    var mockRepository: MockUserRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        sut = GetUserProfileUseCase(repository: mockRepository)
    }

    func test_execute_성공() async throws {
        // Given
        let expectedUser = User(...)
        mockRepository.mockUser = expectedUser

        // When
        let user = try await sut.execute()

        // Then
        XCTAssertEqual(user.name, expectedUser.name)
    }
}
```

</details>

---

### ViewModel 테스트

#### Swift Testing (권장)

```swift
import Testing
@testable import AppProduct

@Suite("User Profile ViewModel Tests")
@MainActor
struct UserProfileViewModelTests {
    let mockGetUseCase: MockGetUserProfileUseCase
    let mockUpdateUseCase: MockUpdateUserProfileUseCase
    let sut: UserProfileViewModel

    init() {
        mockGetUseCase = MockGetUserProfileUseCase()
        mockUpdateUseCase = MockUpdateUserProfileUseCase()
        sut = UserProfileViewModel(
            getUserProfileUseCase: mockGetUseCase,
            updateUserProfileUseCase: mockUpdateUseCase
        )
    }

    @Test("프로필 로딩 성공 시 loaded 상태")
    func loadProfileSuccess() async {
        // Given
        let expectedUser = User(
            id: UserID(value: 1),
            name: "Test User",
            email: "test@example.com",
            bio: "iOS Developer",
            profileImageUrl: nil,
            createdAt: Date()
        )
        mockGetUseCase.mockUser = expectedUser

        // When
        await sut.loadProfile()

        // Then
        guard case .loaded(let user) = sut.userState else {
            Issue.record("Expected loaded state, got \(sut.userState)")
            return
        }

        #expect(user.name == expectedUser.name)
        #expect(user.email == expectedUser.email)
    }

    @Test("프로필 로딩 실패 시 failed 상태")
    func loadProfileFailure() async {
        // Given
        mockGetUseCase.shouldFail = true

        // When
        await sut.loadProfile()

        // Then
        #expect {
            if case .failed = sut.userState {
                return true
            }
            return false
        }
    }

    @Test("초기 상태는 idle")
    func initialState() {
        #expect {
            if case .idle = sut.userState {
                return true
            }
            return false
        }
    }

    @Test("프로필 업데이트 성공")
    func updateProfileSuccess() async {
        // Given
        let updatedUser = User(
            id: UserID(value: 1),
            name: "Updated Name",
            email: "test@example.com",
            bio: "Updated Bio",
            profileImageUrl: nil,
            createdAt: Date()
        )
        mockUpdateUseCase.mockUser = updatedUser

        // When
        await sut.updateProfile(name: "Updated Name", bio: "Updated Bio")

        // Then
        guard case .loaded(let user) = sut.userState else {
            Issue.record("Expected loaded state after update")
            return
        }

        #expect(user.name == "Updated Name")
        #expect(user.bio == "Updated Bio")
    }
}
```

#### XCTest (레거시)

<details>
<summary>XCTest 방식 보기</summary>

```swift
@MainActor
final class UserProfileViewModelTests: XCTestCase {
    var sut: UserProfileViewModel!
    var mockUseCase: MockGetUserProfileUseCase!

    override func setUp() {
        super.setUp()
        mockUseCase = MockGetUserProfileUseCase()
        sut = UserProfileViewModel(
            getUserProfileUseCase: mockUseCase,
            updateUserProfileUseCase: MockUpdateUserProfileUseCase()
        )
    }

    func test_loadProfile_성공() async {
        // Given
        let expectedUser = User(...)
        mockUseCase.mockUser = expectedUser

        // When
        await sut.loadProfile()

        // Then
        if case .loaded(let user) = sut.userState {
            XCTAssertEqual(user.name, expectedUser.name)
        } else {
            XCTFail("Expected loaded state")
        }
    }
}
```

</details>

---

### Swift Testing 주요 특징

#### 1. **간결한 Assertion**

```swift
// XCTest
XCTAssertEqual(user.name, "Test")
XCTAssertNotNil(user.email)
XCTAssertTrue(user.age >= 18)

// Swift Testing
#expect(user.name == "Test")
#expect(user.email != nil)
#expect(user.age >= 18)
```

#### 2. **파라미터화된 테스트**

```swift
@Test("다양한 HTTP 상태 코드 테스트", arguments: [400, 401, 403, 404, 500])
func handleStatusCode(code: Int) async {
    // 각 상태 코드별로 자동 실행
}

@Test(arguments: zip(["Alice", "Bob"], [25, 30]))
func userAge(name: String, age: Int) {
    #expect(age > 0)
}
```

#### 3. **에러 검증**

```swift
// 특정 에러 타입 확인
await #expect {
    try await sut.failingMethod()
} throws: { error in
    error is NetworkError
}

// 에러 케이스 상세 검증
await #expect {
    try await sut.brew(forMinutes: 3)
} throws: { error in
    guard let error = error as? BrewingError,
          case let .needsMoreTime(time) = error else {
        return false
    }
    return time == 4
}
```

#### 4. **태그와 그룹화**

```swift
extension Tag {
    @Tag static var integration: Self
    @Tag static var performance: Self
}

@Test(.tags(.integration))
func integrationTest() { }

@Test(.tags(.performance), .timeLimit(.minutes(5)))
func performanceTest() { }
```

#### 5. **병렬 실행 제어**

```swift
// 기본: 병렬 실행
@Test func parallelTest() { }

// 순차 실행 필요 시
@Test(.serialized)
func serializedTest() { }
```

#### 6. **Suite로 그룹화**

```swift
@Suite("User Feature Tests")
struct UserFeatureTests {
    @Suite("Repository Layer")
    struct RepositoryTests {
        @Test func getUser() { }
        @Test func updateUser() { }
    }
    
    @Suite("UseCase Layer")
    struct UseCaseTests {
        @Test func execute() { }
    }
}
```

### Mock 객체 예시

```swift
// MockMoyaNetworkAdapter
final class MockMoyaNetworkAdapter: MoyaNetworkAdapter {
    var mockResponse: Data?
    var mockStatusCode: Int = 200
    var shouldFail: Bool = false
    
    override func request<T: TargetType>(_ target: T) async throws -> Response {
        if shouldFail {
            throw NetworkError.requestFailed(statusCode: mockStatusCode, data: nil)
        }
        
        return Response(
            statusCode: mockStatusCode,
            data: mockResponse ?? Data()
        )
    }
}

// MockUserRepository
final class MockUserRepository: UserRepositoryProtocol {
    var mockUser: User?
    var shouldFail: Bool = false

    func getMe() async throws -> User {
        if shouldFail {
            throw RepositoryError.serverError(code: "MOCK001", message: "Mock error")
        }

        guard let user = mockUser else {
            throw RepositoryError.serverError(code: nil, message: "No mock data")
        }

        return user
    }
}
```
---

## 체크리스트

새로운 API를 추가할 때 다음 항목들을 확인하세요:

- [ ] Moya TargetType 정의 (DataSources)
- [ ] DTO 정의 및 `toDomain()` 구현 (DTOs)
- [ ] Repository Protocol 정의 (Domain/Interfaces)
- [ ] Repository 구현 (Data/Repositories)
- [ ] UseCase Protocol 정의 (Domain/UseCases)
- [ ] UseCase 구현 (Domain/UseCases/Implementations)
- [ ] DIContainer에 등록
- [ ] ViewModel 작성 (Loadable 패턴 사용)
- [ ] View 작성 (Environment DI 사용)
- [ ] 에러 처리 (Loadable vs ErrorHandler 선택)
- [ ] 유닛 테스트 작성
`
---

## 참고 자료

- [CLAUDE.md](./CLAUDE.md) - 프로젝트 아키텍처 및 코딩 스타일
- [NetworkClient.swift](./AppProduct/AppProduct/Core/NetworkAdapter/NetworkClient/NetworkClient.swift) - JWT 인증 및 토큰 갱신
- [MoyaNetworkAdapter.swift](./AppProduct/AppProduct/Core/NetworkAdapter/TokenRefreshService/MoyaNetworkAdapter.swift) - Moya 어댑터
- [APIResponse.swift](./AppProduct/AppProduct/Core/NetworkAdapter/Base/APIResponse.swift) - 서버 공통 응답 DTO
- [RepositoryError.swift](./AppProduct/AppProduct/Core/Common/Error/Types/RepositoryError.swift) - Repository 계층 에러
- [NetworkError.swift](./AppProduct/AppProduct/Core/Common/Error/Types/NetworkError.swift) - 네트워크 계층 에러
- [Loadable.swift](./AppProduct/AppProduct/Core/Common/Error/Loadable.swift) - 비동기 상태 관리

---

## 자주 묻는 질문 (FAQ)

### Q1. Repository에서 왜 Protocol을 사용하나요?

**A**: SOLID 원칙 중 의존성 역전 원칙(DIP)을 따르기 위함입니다. UseCase가 구체적인 구현(Repository)에 의존하지 않고 추상화(Protocol)에 의존하면:
- 테스트 시 Mock으로 쉽게 교체 가능
- 구현체 변경 시 UseCase 코드 수정 불필요
- 여러 구현체 공존 가능 (로컬 캐시, 원격 서버 등)

### Q2. UseCase가 꼭 필요한가요? Repository를 직접 호출하면 안 되나요?

**A**: UseCase는 비즈니스 로직을 담당합니다. 간단한 CRUD라면 Repository 호출만 하지만, 다음과 같은 경우 UseCase가 필요합니다:
- 여러 Repository 조합 (User + Post Repository)
- 데이터 검증 및 가공
- 캐싱 로직
- 도메인 규칙 적용

### Q3. ViewModel에서 DIContainer를 직접 주입받지 않고 UseCase를 주입받는 이유는?

**A**: 의존성 명시화를 위함입니다:
- ViewModel이 필요한 UseCase만 주입받음
- 테스트 시 필요한 Mock만 생성
- DIContainer 전체 의존성 노출 방지

### Q4. Loadable과 ErrorHandler를 언제 사용하나요?

**A**:
- **Loadable**: 화면 내 에러 표시 (리스트 로딩 실패, 도메인 에러 등)
- **ErrorHandler**: 작업 중단 필요 (세션 만료, 권한 오류, 네트워크 끊김 등)

### Q5. APIResponse는 무엇인가요?

**A**: 서버의 공통 응답 포맷입니다 (Spring 백엔드 `ApiResponse<T>` 매핑):
```json
{
  "success": true,
  "code": "200",
  "message": "성공",
  "result": { /* 실제 데이터 */ }
}
```

모든 API 응답이 이 형식을 따르므로, `APIResponse<T>`를 사용하여 파싱합니다:
```swift
let apiResponse = try JSONDecoder().decode(
    APIResponse<UserDTO>.self,
    from: response.data
)

// unwrap()으로 성공 여부 확인 + result 추출
let userDTO = try apiResponse.unwrap()
```

`unwrap()` 메서드는 `isSuccess`가 false이거나 `result`가 nil일 경우 `RepositoryError.serverError`를 throw합니다.

> **Note**: 이전에 사용하던 `CommonDTO`는 `APIResponse`로 이름이 변경되었습니다.

### Q6. NetworkError, RepositoryError, DomainError의 차이점은?

**A**: 각 에러 타입은 발생하는 계층과 원인이 다릅니다:

| 에러 타입 | 발생 계층 | 원인 | 예시 |
|----------|---------|------|------|
| **NetworkError** | NetworkClient | HTTP 통신 자체 문제 | 인터넷 끊김, 타임아웃, 401 인증 실패, 토큰 갱신 실패 |
| **RepositoryError** | Repository | 서버 응답은 왔으나 비즈니스 실패 | `isSuccess: false`, JSON 디코딩 실패 |
| **DomainError** | UseCase/Domain | 클라이언트 비즈니스 규칙 위반 | 잔액 부족, 권한 없음, 이미 처리됨 |

**판단 기준:**
```
요청이 서버에 도달했나?
├─ NO → NetworkError (noNetwork, timeout, invalidResponse)
└─ YES → 서버가 HTTP 200을 반환했나?
         ├─ NO → NetworkError (requestFailed, unauthorized)
         └─ YES → isSuccess가 true인가?
                  ├─ NO → RepositoryError (serverError)
                  └─ YES → 비즈니스 규칙 통과?
                           ├─ NO → DomainError
                           └─ YES → 성공!
```

**코드 예시:**
```swift
// Repository에서 RepositoryError 발생
func withdraw(amount: Int) async throws -> Balance {
    let response = try await adapter.request(BankAPI.withdraw(amount))
    let apiResponse = try JSONDecoder().decode(
        APIResponse<BalanceDTO>.self,
        from: response.data
    )
    // isSuccess: false → RepositoryError.serverError
    let dto = try apiResponse.unwrap()
    return dto.toDomain()
}

// UseCase에서 DomainError 발생
func execute(amount: Int) async throws -> Balance {
    let currentBalance = try await repository.getBalance()

    // 클라이언트 비즈니스 규칙 검증
    guard currentBalance.amount >= amount else {
        throw DomainError.insufficientBalance  // DomainError
    }

    return try await repository.withdraw(amount)
}
```

**ViewModel에서 처리:**
```swift
@MainActor
func withdraw(amount: Int) async {
    do {
        let balance = try await useCase.execute(amount: amount)
        state = .loaded(balance)
    } catch let error as DomainError {
        // 도메인 에러 → 인라인 표시 (사용자가 조치 가능)
        state = .failed(.domain(error))
    } catch let error as NetworkError {
        // 네트워크 에러 → 연결 문제 안내
        state = .failed(.network(error))
    } catch let error as RepositoryError {
        // 서버 비즈니스 에러 → 서버 메시지 표시
        state = .failed(.repository(error))
    } catch {
        state = .failed(.unknown(message: error.localizedDescription))
    }
}
```

---

## 수정 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-02-04 | 1.1.0 | 에러 타입 시스템 리팩토링 반영 | jaewon Lee |
| | | - `CommonDTO` → `APIResponse` 변경 |  |
| | | - `APIError` 제거, `NetworkError`/`RepositoryError`로 통합 |  |
| | | - `RepositoryError` 정의 업데이트 (`code` 파라미터 추가) |  |
| | | - `NetworkError`에 `noNetwork`, `timeout` 케이스 추가 |  |
| | | - `unwrap()` 메서드 사용법 문서화 |  |
| | | - FAQ Q6 추가: NetworkError/RepositoryError/DomainError 차이점 |  |
| 2026-01-09 | 1.0.0 | 최초 작성 | 제옹(euijjang97) |
