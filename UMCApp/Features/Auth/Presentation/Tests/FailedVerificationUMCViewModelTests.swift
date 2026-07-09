import Testing
import Foundation
import CoreDI
import CoreNetwork
import AuthDomain
import MyPageDomain
import UMCFoundation
@testable import AuthPresentation

@MainActor
@Suite("FailedVerificationUMCViewModel — 승인 대기 화면")
struct FailedVerificationUMCViewModelTests {

    // MARK: - 기존 챌린저 코드 재인증

    @Test("6자리가 아니거나 영숫자가 아니면 재인증 API를 호출하지 않는다")
    func invalidCodeDoesNotCallUseCase() async {
        let registerUseCase = MockRegisterExistingChallengerUseCase()
        let viewModel = makeViewModel(registerExistingChallengerUseCase: registerUseCase)
        viewModel.challengerCode = "abc"

        await viewModel.submitChallengerCode()

        #expect(registerUseCase.callCount == 0)
        #expect(viewModel.alertPrompt?.title == "인증 실패")
    }

    @Test("승인된 프로필이면 성공 프롬프트의 확인 액션이 .main으로 이동한다")
    func successApprovedSetsMainDestinationOnConfirm() async {
        let registerUseCase = MockRegisterExistingChallengerUseCase()
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        fetchMyProfileUseCase.result = .success(makeProfile(generations: ["11"]))
        let viewModel = makeViewModel(
            registerExistingChallengerUseCase: registerUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase
        )
        viewModel.challengerCode = "ABC123"

        await viewModel.submitChallengerCode()

        #expect(registerUseCase.callCount == 1)
        #expect(registerUseCase.lastCode == "ABC123")
        #expect(viewModel.challengerCode == "")
        #expect(viewModel.destination == nil)

        viewModel.alertPrompt?.positiveBtnAction?()
        #expect(viewModel.destination == .main)
    }

    @Test("미승인 프로필이면 대기 안내만 표시하고 화면을 전환하지 않는다")
    func successPendingApprovalStaysOnScreen() async {
        let registerUseCase = MockRegisterExistingChallengerUseCase()
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        fetchMyProfileUseCase.result = .success(makeProfile(generations: []))
        let viewModel = makeViewModel(
            registerExistingChallengerUseCase: registerUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase
        )
        viewModel.challengerCode = "ABC123"

        await viewModel.submitChallengerCode()

        #expect(viewModel.alertPrompt?.message == "코드가 등록되었습니다. 운영진의 최종 승인을 기다려주세요.")
        #expect(viewModel.alertPrompt?.positiveBtnAction == nil)
        #expect(viewModel.destination == nil)
    }

    @Test("알려진 서버 에러 코드는 사용자 메시지로 매핑된다")
    func knownRepositoryErrorMapsToUserMessage() async {
        let registerUseCase = MockRegisterExistingChallengerUseCase()
        registerUseCase.executeResult = .failure(
            RepositoryError.serverError(code: "CHALLENGER-0002", message: "raw")
        )
        let viewModel = makeViewModel(registerExistingChallengerUseCase: registerUseCase)
        viewModel.challengerCode = "ABC123"

        await viewModel.submitChallengerCode()

        #expect(viewModel.alertPrompt?.message == "이미 등록된 사용자입니다.")
    }

    @Test("알려지지 않은 서버 에러 코드는 코드 접두사를 제거한 메시지를 노출한다")
    func unknownRepositoryErrorSanitizesMessage() async {
        let registerUseCase = MockRegisterExistingChallengerUseCase()
        let rawMessage = "CHALLENGER-9999: 알 수 없는 오류"
        registerUseCase.executeResult = .failure(
            RepositoryError.serverError(code: "CHALLENGER-9999", message: rawMessage)
        )
        let viewModel = makeViewModel(registerExistingChallengerUseCase: registerUseCase)
        viewModel.challengerCode = "ABC123"

        await viewModel.submitChallengerCode()

        #expect(viewModel.alertPrompt?.message == "알 수 없는 오류")
    }

    @Test("6자리이지만 영숫자가 아닌 코드는 재인증 API를 호출하지 않는다")
    func sixCharacterNonAlphanumericCodeDoesNotCallUseCase() async {
        let registerUseCase = MockRegisterExistingChallengerUseCase()
        let viewModel = makeViewModel(registerExistingChallengerUseCase: registerUseCase)
        viewModel.challengerCode = "AB-123"

        await viewModel.submitChallengerCode()

        #expect(registerUseCase.callCount == 0)
        #expect(viewModel.alertPrompt?.title == "인증 실패")
    }

    @Test("앞뒤 공백이 포함된 코드는 트리밍 후 재인증 API를 호출한다")
    func whitespacePaddedCodeIsTrimmedBeforeCallingUseCase() async {
        let registerUseCase = MockRegisterExistingChallengerUseCase()
        let fetchMyProfileUseCase = MockFetchMyProfileUseCase()
        fetchMyProfileUseCase.result = .success(makeProfile(generations: ["11"]))
        let viewModel = makeViewModel(
            registerExistingChallengerUseCase: registerUseCase,
            fetchMyProfileUseCase: fetchMyProfileUseCase
        )
        viewModel.challengerCode = " ABC123 "

        await viewModel.submitChallengerCode()

        #expect(registerUseCase.callCount == 1)
        #expect(registerUseCase.lastCode == "ABC123")
    }

    @Test("코드 인증이 진행 중이면 재진입 호출은 API를 다시 호출하지 않는다")
    func duplicateSubmitWhileInFlightIsIgnored() async {
        let slowUseCase = SlowRegisterExistingChallengerUseCase(delayNanoseconds: 50_000_000)
        let viewModel = makeViewModel(registerExistingChallengerUseCase: slowUseCase)
        viewModel.challengerCode = "ABC123"

        let first = Task { await viewModel.submitChallengerCode() }
        await Task.yield()

        await viewModel.submitChallengerCode()
        await first.value

        #expect(slowUseCase.callCount == 1)
    }

    // MARK: - 로그아웃

    @Test("로그아웃 프롬프트는 파괴적 확인으로 구성된다")
    func presentLogoutPromptBuildsDestructiveConfirmation() {
        let viewModel = makeViewModel()

        viewModel.presentLogoutPrompt()

        #expect(viewModel.alertPrompt?.title == "로그아웃")
        #expect(viewModel.alertPrompt?.isPositiveBtnDestructive == true)
    }

    @Test("로그아웃 확인 시 토큰을 정리하고 로그인 화면으로 이동한다")
    func logoutConfirmClearsTokenAndNavigatesToLogin() async throws {
        let tokenStore = FakeTokenStore()
        let viewModel = makeViewModel(tokenStore: tokenStore)

        viewModel.presentLogoutPrompt()
        viewModel.alertPrompt?.positiveBtnAction?()

        try await waitUntil { viewModel.destination == .login }

        #expect(viewModel.isLoggingOut == false)
        #expect(await tokenStore.clearCallCount == 1)
    }

    @Test("로그아웃 실패 시 ErrorHandler에 에러를 전달하고 화면을 전환하지 않는다")
    func logoutFailureReportsErrorWithoutNavigating() async throws {
        let tokenStore = FakeTokenStore()
        await tokenStore.setClearError(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(errorHandler: errorHandler, tokenStore: tokenStore)

        viewModel.presentLogoutPrompt()
        viewModel.alertPrompt?.positiveBtnAction?()

        try await waitUntil { errorHandler.currentError != nil }

        #expect(viewModel.destination == nil)
        #expect(viewModel.isLoggingOut == false)
    }

    // MARK: - 회원 탈퇴

    @Test("회원 탈퇴 프롬프트는 파괴적 확인으로 구성된다")
    func presentDeleteAccountPromptBuildsDestructiveConfirmation() {
        let viewModel = makeViewModel()

        viewModel.presentDeleteAccountPrompt()

        #expect(viewModel.alertPrompt?.title == "계정 삭제")
        #expect(viewModel.alertPrompt?.isPositiveBtnDestructive == true)
    }

    @Test("회원 탈퇴 성공 시 로그아웃까지 수행하고 로그인 화면으로 이동한다")
    func deleteAccountSuccessLogsOutAndNavigatesToLogin() async throws {
        let deleteMemberUseCase = MockDeleteMemberUseCase()
        let tokenStore = FakeTokenStore()
        let viewModel = makeViewModel(
            deleteMemberUseCase: deleteMemberUseCase,
            tokenStore: tokenStore
        )

        viewModel.presentDeleteAccountPrompt()
        viewModel.alertPrompt?.positiveBtnAction?()

        try await waitUntil { viewModel.destination == .login }

        #expect(deleteMemberUseCase.callCount == 1)
        #expect(await tokenStore.clearCallCount == 1)
        #expect(viewModel.isDeletingAccount == false)
    }

    @Test("회원 탈퇴는 성공했지만 로그아웃(토큰 정리)이 실패하면 화면을 전환하지 않는다")
    func deleteAccountSucceedsButLogoutFailsReportsErrorWithoutNavigating() async throws {
        let deleteMemberUseCase = MockDeleteMemberUseCase()
        let tokenStore = FakeTokenStore()
        await tokenStore.setClearError(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            errorHandler: errorHandler,
            deleteMemberUseCase: deleteMemberUseCase,
            tokenStore: tokenStore
        )

        viewModel.presentDeleteAccountPrompt()
        viewModel.alertPrompt?.positiveBtnAction?()

        try await waitUntil { errorHandler.currentError != nil }

        #expect(deleteMemberUseCase.callCount == 1)
        #expect(viewModel.destination == nil)
        #expect(viewModel.isDeletingAccount == false)
    }

    @Test("회원 탈퇴 실패 시 로그아웃을 수행하지 않고 에러를 전달한다")
    func deleteAccountFailureDoesNotLogOut() async throws {
        let deleteMemberUseCase = MockDeleteMemberUseCase()
        deleteMemberUseCase.result = .failure(DummyError())
        let tokenStore = FakeTokenStore()
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            errorHandler: errorHandler,
            deleteMemberUseCase: deleteMemberUseCase,
            tokenStore: tokenStore
        )

        viewModel.presentDeleteAccountPrompt()
        viewModel.alertPrompt?.positiveBtnAction?()

        try await waitUntil { errorHandler.currentError != nil }

        #expect(viewModel.destination == nil)
        #expect(await tokenStore.clearCallCount == 0)
    }
}

// MARK: - Helpers

private struct DummyError: Error {}

/// 콜백 기반 비동기(`Task { @MainActor in ... }`) 완료를 폴링으로 대기합니다.
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
    errorHandler: ErrorHandler? = nil,
    registerExistingChallengerUseCase: RegisterExistingChallengerUseCaseProtocol? = nil,
    fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol? = nil,
    deleteMemberUseCase: DeleteMemberUseCaseProtocol? = nil,
    tokenStore: FakeTokenStore? = nil
) -> FailedVerificationUMCViewModel {
    let registerUseCase = registerExistingChallengerUseCase
        ?? MockRegisterExistingChallengerUseCase()
    let fetchUseCase = fetchMyProfileUseCase ?? MockFetchMyProfileUseCase()
    let deleteUseCase = deleteMemberUseCase ?? MockDeleteMemberUseCase()
    let store = tokenStore ?? FakeTokenStore()

    let container = DIContainer()
    container.register(RegisterExistingChallengerUseCaseProtocol.self) { registerUseCase }
    container.register(FetchMyProfileUseCaseProtocol.self) { fetchUseCase }
    container.register(DeleteMemberUseCaseProtocol.self) { deleteUseCase }
    container.register(NetworkClient.self) {
        NetworkClient(tokenStore: store, refreshService: FakeTokenRefreshService())
    }

    return FailedVerificationUMCViewModel(
        container: container,
        errorHandler: errorHandler ?? ErrorHandler()
    )
}

private func makeProfile(generations: [String]) -> Profile {
    Profile(memberId: "1", name: "홍길동", nickname: "길동이", generations: generations)
}

// MARK: - Mocks — UseCase

private final class MockRegisterExistingChallengerUseCase:
    RegisterExistingChallengerUseCaseProtocol, @unchecked Sendable {
    var executeResult: Result<Void, Error> = .success(())
    private(set) var callCount = 0
    private(set) var lastCode: String?

    func execute(code: String) async throws {
        callCount += 1
        lastCode = code
        try executeResult.get()
    }
}

/// 재진입 가드 검증을 위해 인위적인 지연을 주는 재인증 UseCase.
private final class SlowRegisterExistingChallengerUseCase:
    RegisterExistingChallengerUseCaseProtocol, @unchecked Sendable {
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

    func execute(code: String) async throws {
        lock.lock()
        _callCount += 1
        lock.unlock()
        try await Task.sleep(nanoseconds: delayNanoseconds)
    }
}

private final class MockFetchMyProfileUseCase: FetchMyProfileUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error { case notStubbed }

    var result: Result<Profile, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0

    func execute() async throws -> Profile {
        callCount += 1
        return try result.get()
    }
}

private final class MockDeleteMemberUseCase: DeleteMemberUseCaseProtocol, @unchecked Sendable {
    var result: Result<Void, Error> = .success(())
    private(set) var callCount = 0

    func execute() async throws {
        callCount += 1
        try result.get()
    }
}

// MARK: - Fakes — NetworkClient 의존성

private actor FakeTokenStore: TokenStore {
    private(set) var clearCallCount = 0
    private var clearError: Error?

    func setClearError(_ error: Error) {
        clearError = error
    }

    func getAccessToken() async -> String? { nil }
    func getRefreshToken() async -> String? { nil }
    func save(accessToken: String, refreshToken: String) async throws {}

    func clear() async throws {
        clearCallCount += 1
        if let clearError {
            throw clearError
        }
    }
}

private struct FakeTokenRefreshService: TokenRefreshService {
    func refresh(_ refreshToken: String) async throws -> TokenPair {
        throw DummyError()
    }
}
