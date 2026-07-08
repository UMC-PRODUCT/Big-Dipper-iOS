import Testing
import Foundation
import CoreDI
import CoreNetwork
import AuthDomain
import UMCFoundation
@testable import AuthPresentation

@MainActor
@Suite("LoginViewModel — 카카오 로그인 상태 전이")
struct LoginViewModelKakaoTests {

    @Test("초기 상태는 .idle")
    func initialStateIsIdle() {
        let viewModel = makeViewModel()
        #expect(viewModel.loginState == .idle)
        #expect(viewModel.alertPrompt == nil)
    }

    @Test("기존 회원 + 승인됨 → .loaded(profile)")
    func successApprovedSetsLoaded() async {
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeKakaoResult = .success(.existingMember)
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        let profile = makeProfile(generations: ["11"])
        fetchMyProfileUseCase.result = .success(profile)
        let viewModel = makeViewModel(
            loginUseCase: loginUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase
        )

        await viewModel.loginWithKakao()

        #expect(viewModel.loginState == .loaded(profile))
        #expect(viewModel.alertPrompt == nil)
    }

    @Test("기존 회원 + 승인 대기(기수 없음) → .failed(.auth(.pendingApproval))")
    func pendingApprovalSetsFailedPendingApproval() async {
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeKakaoResult = .success(.existingMember)
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        fetchMyProfileUseCase.result = .success(makeProfile(generations: []))
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            loginUseCase: loginUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase,
            errorHandler: errorHandler
        )

        await viewModel.loginWithKakao()

        #expect(viewModel.loginState == .failed(.auth(.pendingApproval)))
        // #911 임시 정책 — pendingApproval은 인라인 상태로만 표현하고 Alert는 띄우지 않는다.
        #expect(errorHandler.currentError == nil)
    }

    @Test("신규 회원 → 화면 전환 없이 .idle 유지 + 안내 alertPrompt 노출")
    func newMemberPresentsGuidanceWithoutTransition() async {
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeKakaoResult = .success(.newMember(verificationToken: "verify-token"))
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        let viewModel = makeViewModel(
            loginUseCase: loginUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase
        )

        await viewModel.loginWithKakao()

        #expect(viewModel.loginState == .idle)
        #expect(viewModel.alertPrompt != nil)
        #expect(fetchMyProfileUseCase.callCount == 0)
    }

    @Test("사용자 취소(SocialLoginError.cancelled) → .idle 복귀, ErrorHandler Alert 없음")
    func cancelledSetsIdleWithoutErrorAlert() async {
        let kakaoLoginManager = MockKakaoLoginManager()
        kakaoLoginManager.error = SocialLoginError.cancelled
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            errorHandler: errorHandler,
            kakaoLoginManager: kakaoLoginManager
        )

        await viewModel.loginWithKakao()

        #expect(viewModel.loginState == .idle)
        #expect(errorHandler.currentError == nil)
    }

    @Test("일반 에러 → .idle 복귀 + ErrorHandler Alert 노출")
    func genericFailureSetsIdleWithErrorAlert() async {
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeKakaoResult = .failure(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(loginUseCase: loginUseCase, errorHandler: errorHandler)

        await viewModel.loginWithKakao()

        #expect(viewModel.loginState == .idle)
        #expect(errorHandler.currentError != nil)
    }

    @Test("로딩 중 중복 호출은 무시 (UseCase 1회만 호출)")
    func duplicateCallWhileLoadingIsIgnored() async {
        let kakaoLoginManager = SlowKakaoLoginManager(delayNanoseconds: 50_000_000)
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeKakaoResult = .success(.existingMember)
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        fetchMyProfileUseCase.result = .success(makeProfile(generations: ["11"]))
        let viewModel = makeViewModel(
            loginUseCase: loginUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase,
            kakaoLoginManager: kakaoLoginManager
        )

        let first = Task { await viewModel.loginWithKakao() }
        await Task.yield()

        await viewModel.loginWithKakao()
        await first.value

        #expect(kakaoLoginManager.callCount == 1)
        #expect(loginUseCase.executeKakaoCallCount == 1)
    }
}

@MainActor
@Suite("LoginViewModel — Google/Apple 로그인 위임")
struct LoginViewModelOtherProvidersTests {

    @Test("Google 로그인 성공 → .loaded(profile)")
    func googleLoginSuccessSetsLoaded() async {
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeGoogleResult = .success(.existingMember)
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        let profile = makeProfile(generations: ["12"])
        fetchMyProfileUseCase.result = .success(profile)
        let viewModel = makeViewModel(
            loginUseCase: loginUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase
        )

        await viewModel.loginWithGoogle()

        #expect(viewModel.loginState == .loaded(profile))
    }

    @Test("Apple 로그인 성공 → .loaded(profile)")
    func appleLoginSuccessSetsLoaded() async throws {
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeAppleResult = .success(.existingMember)
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        let profile = makeProfile(generations: ["13"])
        fetchMyProfileUseCase.result = .success(profile)
        let appleLoginManager = MockAppleLoginManager()
        let viewModel = makeViewModel(
            loginUseCase: loginUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase,
            appleLoginManager: appleLoginManager
        )

        viewModel.loginWithApple()
        #expect(appleLoginManager.signWithAppleCallCount == 1)

        appleLoginManager.simulateSuccess(authorizationCode: "auth-code", email: nil, fullName: nil)
        try await waitUntil { viewModel.loginState.isComplete }

        #expect(viewModel.loginState == .loaded(profile))
        #expect(loginUseCase.executeAppleCallCount == 1)
    }

    @Test("Apple 로그인 취소 → .idle 복귀, ErrorHandler Alert 없음")
    func appleLoginCancelledSetsIdleWithoutErrorAlert() async throws {
        let appleLoginManager = MockAppleLoginManager()
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(errorHandler: errorHandler, appleLoginManager: appleLoginManager)

        viewModel.loginWithApple()
        appleLoginManager.simulateFailure(SocialLoginError.cancelled)
        try await waitUntil { viewModel.loginState.isIdle }

        #expect(viewModel.loginState == .idle)
        #expect(errorHandler.currentError == nil)
    }
}

// MARK: - Helpers

private struct DummyError: Error {}

/// 콜백 기반 비동기(Apple `Task { @MainActor in ... }`) 완료를 폴링으로 대기합니다.
@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() {
        if ContinuousClock.now >= deadline {
            Issue.record("waitUntil 타임아웃")
            return
        }
        await Task.yield()
    }
}

@MainActor
private func makeViewModel(
    loginUseCase: LoginUseCaseProtocol? = nil,
    fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil,
    kakaoLoginManager: KakaoLoginManaging? = nil,
    appleLoginManager: AppleLoginManaging? = nil,
    googleLoginManager: GoogleLoginManaging? = nil
) -> LoginViewModel {
    // 기본값 초기화 자체가 MainActor 격리(예: GoogleLoginManaging)를 요구하므로
    // 파라미터 기본값이 아닌 함수 본문(@MainActor 컨텍스트)에서 생성한다.
    let loginUseCase = loginUseCase ?? MockLoginUseCase()
    let fetchMyProfileUseCase = fetchMyProfileUseCase ?? MockFetchMyProfileUseCase()
    let errorHandler = errorHandler ?? ErrorHandler()
    let kakaoLoginManager = kakaoLoginManager ?? MockKakaoLoginManager()
    let appleLoginManager = appleLoginManager ?? MockAppleLoginManager()
    let googleLoginManager = googleLoginManager ?? MockGoogleLoginManager()

    let container = DIContainer()
    container.register(LoginUseCaseProtocol.self) { loginUseCase }
    container.register(FetchMyProfileUseCaseProtocol.self) { fetchMyProfileUseCase }
    return LoginViewModel(
        container: container,
        errorHandler: errorHandler,
        kakaoLoginManager: kakaoLoginManager,
        appleLoginManager: appleLoginManager,
        googleLoginManager: googleLoginManager
    )
}

private func makeProfile(generations: [String]) -> Profile {
    Profile(memberId: "1", name: "홍길동", nickname: "길동이", generations: generations)
}

// MARK: - Mocks — UseCase

private final class MockLoginUseCase: LoginUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var executeKakaoResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var executeKakaoCallCount = 0

    var executeAppleResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var executeAppleCallCount = 0

    var executeGoogleResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var executeGoogleCallCount = 0

    func executeKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        executeKakaoCallCount += 1
        return try executeKakaoResult.get()
    }

    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        executeAppleCallCount += 1
        return try executeAppleResult.get()
    }

    func executeGoogle(accessToken: String) async throws -> OAuthLoginResult {
        executeGoogleCallCount += 1
        return try executeGoogleResult.get()
    }
}

private final class MockFetchMyProfileUseCase: FetchMyProfileUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Profile, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0

    func execute() async throws -> Profile {
        callCount += 1
        return try result.get()
    }
}

// MARK: - Mocks — 소셜 로그인 매니저

private final class MockKakaoLoginManager: KakaoLoginManaging, @unchecked Sendable {
    var accessToken = "kakao-token"
    var email = "kakao@umc.dev"
    var error: Error?
    private(set) var callCount = 0

    func login() async throws -> (accessToken: String, email: String) {
        callCount += 1
        if let error { throw error }
        return (accessToken, email)
    }
}

/// 로딩 중 중복 호출 방지를 검증하기 위해 인위적인 지연을 주는 Kakao 매니저.
private final class SlowKakaoLoginManager: KakaoLoginManaging, @unchecked Sendable {
    private let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func login() async throws -> (accessToken: String, email: String) {
        lock.lock()
        _callCount += 1
        lock.unlock()
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return ("kakao-token", "kakao@umc.dev")
    }
}

private final class MockGoogleLoginManager: GoogleLoginManaging, @unchecked Sendable {
    var accessToken = "google-token"
    var email: String?
    var error: Error?
    private(set) var callCount = 0

    func login() async throws -> (accessToken: String, email: String?) {
        callCount += 1
        if let error { throw error }
        return (accessToken, email)
    }
}

private final class MockAppleLoginManager: AppleLoginManaging {
    var onAuthorizationCompleted: ((String, String?, String?) -> Void)?
    var onAuthorizationFailed: ((Error) -> Void)?
    private(set) var signWithAppleCallCount = 0

    func signWithApple() {
        signWithAppleCallCount += 1
    }

    func simulateSuccess(authorizationCode: String, email: String?, fullName: String?) {
        onAuthorizationCompleted?(authorizationCode, email, fullName)
    }

    func simulateFailure(_ error: Error) {
        onAuthorizationFailed?(error)
    }
}
