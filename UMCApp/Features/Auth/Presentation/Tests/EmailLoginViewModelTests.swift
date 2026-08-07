//
//  EmailLoginViewModelTests.swift
//  AuthPresentationTests
//
//  Created by euijjang97 on 7/31/26.
//

import Testing
import Foundation
import CoreDI
import CoreDomain
import AuthDomain
import UMCFoundation
@testable import AuthPresentation

@MainActor
@Suite("EmailLoginViewModel — 이메일 로그인 상태 전이")
struct EmailLoginViewModelTests {

    @Test("초기 상태는 .idle이고 메시지가 모두 비어 있다")
    func initialStateIsIdle() {
        let viewModel = makeViewModel()

        #expect(viewModel.loginState == .idle)
        #expect(viewModel.loginErrorMessage == nil)
        #expect(viewModel.emailGuideMessage == nil)
        #expect(viewModel.passwordGuideMessage == nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test("이메일과 비밀번호가 모두 채워져야 canSubmit이 true (공백만 입력은 false)")
    func canSubmitRequiresBothFields() {
        let viewModel = makeViewModel()

        viewModel.emailInput = "   "
        viewModel.passwordInput = "password"
        #expect(viewModel.canSubmit == false)

        viewModel.emailInput = "member@umc.dev"
        viewModel.passwordInput = ""
        #expect(viewModel.canSubmit == false)

        viewModel.passwordInput = "password"
        #expect(viewModel.canSubmit)
    }

    @Test("빈 입력으로 로그인 시도 → 가이드 메시지 노출, UseCase 미호출")
    func emptyInputShowsGuideMessages() async {
        let loginByEmailUseCase = MockLoginByEmailUseCase()
        let viewModel = makeViewModel(loginByEmailUseCase: loginByEmailUseCase)

        await viewModel.loginWithEmail()

        #expect(viewModel.emailGuideMessage == "이메일을 입력해 주세요.")
        #expect(viewModel.passwordGuideMessage == "비밀번호를 입력해 주세요.")
        #expect(viewModel.loginState == .idle)
        #expect(loginByEmailUseCase.callCount == 0)
    }

    @Test("로그인 성공 + 승인됨 → .loaded(profile), 프로필 로컬 저장소 동기화 1회 수행")
    func successApprovedSetsLoaded() async {
        let loginByEmailUseCase = MockLoginByEmailUseCase()
        loginByEmailUseCase.result = .success(LoginByIdPwResult(memberId: "1"))
        let fetchMemberProfileUseCase = MockFetchMemberProfileUseCase()
        let profile = makeProfile(generations: ["11"])
        fetchMemberProfileUseCase.result = .success(profile)
        let syncProfileStorageUseCase = MockSyncProfileStorageUseCase()
        let viewModel = makeViewModel(
            loginByEmailUseCase: loginByEmailUseCase,
            fetchMemberProfileUseCase: fetchMemberProfileUseCase,
            syncProfileStorageUseCase: syncProfileStorageUseCase
        )
        viewModel.emailInput = "  member@umc.dev  "
        viewModel.passwordInput = "password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginState == .loaded(profile))
        #expect(viewModel.loginErrorMessage == nil)
        #expect(loginByEmailUseCase.receivedEmail == "member@umc.dev")
        #expect(loginByEmailUseCase.receivedPassword == "password")
        #expect(syncProfileStorageUseCase.executeCallCount == 1)
        #expect(syncProfileStorageUseCase.receivedProfile == profile)
    }

    @Test("로그인 성공 + 승인 대기(기수 없음) → .failed(.auth(.pendingApproval)), 동기화 없음")
    func successPendingApprovalSetsFailed() async {
        let loginByEmailUseCase = MockLoginByEmailUseCase()
        loginByEmailUseCase.result = .success(LoginByIdPwResult(memberId: "1"))
        let fetchMemberProfileUseCase = MockFetchMemberProfileUseCase()
        fetchMemberProfileUseCase.result = .success(makeProfile(generations: []))
        let syncProfileStorageUseCase = MockSyncProfileStorageUseCase()
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            loginByEmailUseCase: loginByEmailUseCase,
            fetchMemberProfileUseCase: fetchMemberProfileUseCase,
            syncProfileStorageUseCase: syncProfileStorageUseCase,
            errorHandler: errorHandler
        )
        viewModel.emailInput = "member@umc.dev"
        viewModel.passwordInput = "password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginState == .failed(.auth(.pendingApproval)))
        #expect(syncProfileStorageUseCase.executeCallCount == 0)
        #expect(errorHandler.currentError == nil)
    }

    @Test("AUTHENTICATION-0022 → 자격 증명 인라인 메시지, Alert 없음")
    func invalidCredentialShowsInlineMessage() async {
        let error = RepositoryError.serverError(
            code: "AUTHENTICATION-0022",
            message: "일치하는 회원이 없습니다"
        )
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            loginByEmailUseCase: stubbedUseCase(failure: error),
            errorHandler: errorHandler
        )
        viewModel.emailInput = "member@umc.dev"
        viewModel.passwordInput = "wrong-password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginErrorMessage == "이메일 또는 비밀번호가 올바르지 않습니다.")
        #expect(viewModel.loginState == .failed(.repository(error)))
        #expect(errorHandler.currentError == nil)
    }

    @Test("AUTHENTICATION-0025 → 이메일 형식 인라인 메시지")
    func invalidEmailFormatShowsInlineMessage() async {
        let error = RepositoryError.serverError(code: "AUTHENTICATION-0025", message: nil)
        let viewModel = makeViewModel(loginByEmailUseCase: stubbedUseCase(failure: error))
        viewModel.emailInput = "not-an-email"
        viewModel.passwordInput = "password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginErrorMessage == "이메일 형식이 올바르지 않습니다.")
        #expect(viewModel.loginState == .failed(.repository(error)))
    }

    @Test("매핑되지 않은 서버 에러 코드 → 서버 message를 그대로 인라인 노출")
    func unmappedServerErrorUsesServerMessage() async {
        let error = RepositoryError.serverError(code: "AUTHENTICATION-9999", message: "잠긴 계정입니다")
        let viewModel = makeViewModel(loginByEmailUseCase: stubbedUseCase(failure: error))
        viewModel.emailInput = "member@umc.dev"
        viewModel.passwordInput = "password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginErrorMessage == "잠긴 계정입니다")
    }

    @Test("AppError.repository로 감싸진 에러도 인라인 메시지 경로로 처리")
    func wrappedRepositoryErrorUsesInlineMessage() async {
        let repositoryError = RepositoryError.serverError(
            code: "AUTHENTICATION-0022",
            message: nil
        )
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            loginByEmailUseCase: stubbedUseCase(failure: AppError.repository(repositoryError)),
            errorHandler: errorHandler
        )
        viewModel.emailInput = "member@umc.dev"
        viewModel.passwordInput = "password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginErrorMessage == "이메일 또는 비밀번호가 올바르지 않습니다.")
        #expect(viewModel.loginState == .failed(.repository(repositoryError)))
        #expect(errorHandler.currentError == nil)
    }

    @Test("그 외 에러 → .idle 복귀 + ErrorHandler Alert 노출")
    func unexpectedFailureSetsIdleWithErrorAlert() async {
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            loginByEmailUseCase: stubbedUseCase(failure: DummyError()),
            errorHandler: errorHandler
        )
        viewModel.emailInput = "member@umc.dev"
        viewModel.passwordInput = "password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginState == .idle)
        #expect(viewModel.loginErrorMessage == nil)
        #expect(errorHandler.currentError != nil)
    }

    @Test("프로필 조회 실패 → .idle 복귀 + ErrorHandler Alert 노출")
    func profileFetchFailureSetsIdleWithErrorAlert() async {
        let loginByEmailUseCase = MockLoginByEmailUseCase()
        loginByEmailUseCase.result = .success(LoginByIdPwResult(memberId: "1"))
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            loginByEmailUseCase: loginByEmailUseCase,
            errorHandler: errorHandler
        )
        viewModel.emailInput = "member@umc.dev"
        viewModel.passwordInput = "password"

        await viewModel.loginWithEmail()

        #expect(viewModel.loginState == .idle)
        #expect(errorHandler.currentError != nil)
    }

    @Test("가이드 메시지 clear 함수가 각각 해당 메시지만 지운다")
    func clearGuideMessages() async {
        let viewModel = makeViewModel()

        await viewModel.loginWithEmail()
        #expect(viewModel.emailGuideMessage != nil)
        #expect(viewModel.passwordGuideMessage != nil)

        viewModel.clearEmailGuide()
        #expect(viewModel.emailGuideMessage == nil)
        #expect(viewModel.passwordGuideMessage != nil)

        viewModel.clearPasswordGuide()
        #expect(viewModel.passwordGuideMessage == nil)
    }
}

// MARK: - Helpers

private struct DummyError: Error {}

@MainActor
private func makeViewModel(
    loginByEmailUseCase: LoginByEmailUseCaseProtocol? = nil,
    fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol? = nil,
    syncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil
) -> EmailLoginViewModel {
    let loginByEmailUseCase = loginByEmailUseCase ?? MockLoginByEmailUseCase()
    let fetchMemberProfileUseCase = fetchMemberProfileUseCase ?? MockFetchMemberProfileUseCase()
    let syncProfileStorageUseCase = syncProfileStorageUseCase ?? MockSyncProfileStorageUseCase()
    let errorHandler = errorHandler ?? ErrorHandler()

    let container = DIContainer()
    container.register(LoginByEmailUseCaseProtocol.self) { loginByEmailUseCase }
    container.register(FetchMemberProfileUseCaseProtocol.self) { fetchMemberProfileUseCase }
    container.register(SyncProfileStorageUseCaseProtocol.self) { syncProfileStorageUseCase }
    return EmailLoginViewModel(container: container, errorHandler: errorHandler)
}

private func stubbedUseCase(failure: Error) -> MockLoginByEmailUseCase {
    let useCase = MockLoginByEmailUseCase()
    useCase.result = .failure(failure)
    return useCase
}

private func makeProfile(generations: [String]) -> Profile {
    Profile(memberId: "1", name: "홍길동", nickname: "길동이", generations: generations)
}

// MARK: - Mocks — UseCase

private final class MockLoginByEmailUseCase: LoginByEmailUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<LoginByIdPwResult, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedEmail: String?
    private(set) var receivedPassword: String?

    func execute(email: String, password: String) async throws -> LoginByIdPwResult {
        callCount += 1
        receivedEmail = email
        receivedPassword = password
        return try result.get()
    }
}

private final class MockFetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Profile, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0

    func execute() async throws -> Profile {
        callCount += 1
        return try result.get()
    }
}

private final class MockSyncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol,
    @unchecked Sendable {
    private(set) var executeCallCount = 0
    private(set) var receivedProfile: Profile?

    func execute(profile: Profile) {
        executeCallCount += 1
        receivedProfile = profile
    }
}
