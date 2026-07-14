//
//  ResetPasswordViewModelTests.swift
//  AuthPresentationTests
//
//  Created by euijjang97 on 7/10/26.
//

import Testing
import Foundation
import CoreDI
import AuthDomain
import UMCFoundation
@testable import AuthPresentation

@MainActor
@Suite("ResetPasswordViewModel — 이메일 인증")
struct ResetPasswordViewModelEmailVerificationTests {

    @Test("인증번호 발송 성공 시 emailVerificationId가 저장된다")
    func requestEmailVerificationStoresId() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let viewModel = makeViewModel(sendEmailVerificationUseCase: sendEmailVerificationUseCase)
        viewModel.emailVerificationFlow.email = "member@umc.dev"

        try await viewModel.emailVerificationFlow.requestEmailVerification()

        #expect(sendEmailVerificationUseCase.callCount == 1)
        #expect(sendEmailVerificationUseCase.receivedPurpose == .passwordReset)
        #expect(viewModel.emailVerificationFlow.emailVerificationId == "verify-id-1")
    }

    @Test("인증코드 검증 성공 시 토큰이 저장되고 isEmailVerified가 true가 된다")
    func verifyEmailCodeMarksVerified() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token-1")
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase
        )
        viewModel.emailVerificationFlow.email = "member@umc.dev"
        try await viewModel.emailVerificationFlow.requestEmailVerification()

        try await viewModel.emailVerificationFlow.verifyEmailCode("123456")

        #expect(viewModel.emailVerificationFlow.isEmailVerified == true)
        #expect(viewModel.emailVerificationFlow.emailVerificationToken == "verify-token-1")
    }

    @Test("이메일 변경 시 인증 상태가 초기화된다")
    func emailChangeResetsVerificationState() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token-1")
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase
        )
        viewModel.emailVerificationFlow.email = "member@umc.dev"
        try await viewModel.emailVerificationFlow.requestEmailVerification()
        try await viewModel.emailVerificationFlow.verifyEmailCode("123456")
        #expect(viewModel.emailVerificationFlow.isEmailVerified == true)

        viewModel.emailVerificationFlow.email = "changed@umc.dev"
        viewModel.emailVerificationFlow.handleEmailChanged()

        #expect(viewModel.emailVerificationFlow.isEmailVerified == false)
        #expect(viewModel.emailVerificationFlow.emailVerificationId == nil)
        #expect(viewModel.emailVerificationFlow.emailVerificationToken == nil)
    }
}

@MainActor
@Suite("ResetPasswordViewModel — canSubmit")
struct ResetPasswordViewModelCanSubmitTests {

    @Test("이메일 인증, 비밀번호 검증을 모두 충족하면 canSubmit이 true다")
    func allConditionsSatisfiedMakesCanSubmitTrue() async throws {
        let viewModel = try await makeVerifiedViewModel()
        viewModel.newPassword = "newPassword1234"
        viewModel.newPasswordConfirm = "newPassword1234"

        #expect(viewModel.canSubmit == true)
    }

    @Test("이메일 인증 전이면 canSubmit이 false다")
    func emailNotVerifiedBlocksSubmit() {
        let viewModel = makeViewModel()
        viewModel.newPassword = "newPassword1234"
        viewModel.newPasswordConfirm = "newPassword1234"

        #expect(viewModel.canSubmit == false)
    }

    @Test("비밀번호가 8자 미만이면 canSubmit이 false다")
    func shortPasswordBlocksSubmit() async throws {
        let viewModel = try await makeVerifiedViewModel()
        viewModel.newPassword = "short"
        viewModel.newPasswordConfirm = "short"

        #expect(viewModel.isPasswordValid == false)
        #expect(viewModel.canSubmit == false)
    }

    @Test("비밀번호가 정확히 8자면 isPasswordValid가 true다 (경계값)")
    func exactlyMinimumLengthPasswordIsValid() async throws {
        let viewModel = try await makeVerifiedViewModel()
        viewModel.newPassword = "exactly8"
        viewModel.newPasswordConfirm = "exactly8"

        #expect(viewModel.isPasswordValid == true)
        #expect(viewModel.canSubmit == true)
    }

    @Test("비밀번호 확인이 일치하지 않으면 canSubmit이 false다")
    func passwordMismatchBlocksSubmit() async throws {
        let viewModel = try await makeVerifiedViewModel()
        viewModel.newPassword = "newPassword1234"
        viewModel.newPasswordConfirm = "different-password"

        #expect(viewModel.isPasswordConfirmed == false)
        #expect(viewModel.canSubmit == false)
    }
}

@MainActor
@Suite("ResetPasswordViewModel — 비밀번호 재설정")
struct ResetPasswordViewModelResetPasswordTests {

    @Test("canSubmit이 false면 resetPassword()는 아무 것도 하지 않는다")
    func resetPasswordNoOpsWhenCanSubmitFalse() async {
        let resetPasswordUseCase = MockResetPasswordUseCase()
        let viewModel = makeViewModel(resetPasswordUseCase: resetPasswordUseCase)

        await viewModel.resetPassword()

        #expect(resetPasswordUseCase.callCount == 0)
        #expect(viewModel.resetPasswordState == .idle)
    }

    @Test("재설정 성공 → resetPasswordState.loaded(true)")
    func resetPasswordSuccessSetsLoaded() async throws {
        let resetPasswordUseCase = MockResetPasswordUseCase()
        resetPasswordUseCase.result = .success(())
        let viewModel = try await makeVerifiedViewModel(resetPasswordUseCase: resetPasswordUseCase)
        viewModel.newPassword = "newPassword1234"
        viewModel.newPasswordConfirm = "newPassword1234"

        await viewModel.resetPassword()

        #expect(viewModel.resetPasswordState == .loaded(true))
        #expect(resetPasswordUseCase.callCount == 1)
        #expect(resetPasswordUseCase.receivedEmailVerificationToken == "verify-token-1")
        #expect(resetPasswordUseCase.receivedNewPassword == "newPassword1234")
    }

    @Test("재설정 실패 → resetPasswordState.idle 복귀 + ErrorHandler Alert 노출")
    func resetPasswordFailureSetsIdleWithErrorAlert() async throws {
        let resetPasswordUseCase = MockResetPasswordUseCase()
        resetPasswordUseCase.result = .failure(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = try await makeVerifiedViewModel(
            resetPasswordUseCase: resetPasswordUseCase,
            errorHandler: errorHandler
        )
        viewModel.newPassword = "newPassword1234"
        viewModel.newPasswordConfirm = "newPassword1234"

        await viewModel.resetPassword()

        #expect(viewModel.resetPasswordState == .idle)
        #expect(errorHandler.currentError != nil)
    }
}

// MARK: - Helpers

private struct DummyError: Error {}

@MainActor
private func makeViewModel(
    sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol? = nil,
    verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol? = nil,
    resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol? = nil,
    resetPasswordUseCase: ResetPasswordUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil
) -> ResetPasswordViewModel {
    let container = DIContainer()
    container.register(SendEmailVerificationUseCaseProtocol.self) {
        sendEmailVerificationUseCase ?? MockSendEmailVerificationUseCase()
    }
    container.register(VerifyEmailCodeUseCaseProtocol.self) {
        verifyEmailCodeUseCase ?? MockVerifyEmailCodeUseCase()
    }
    container.register(ResendEmailVerificationUseCaseProtocol.self) {
        resendEmailVerificationUseCase ?? MockResendEmailVerificationUseCase()
    }
    container.register(ResetPasswordUseCaseProtocol.self) {
        resetPasswordUseCase ?? MockResetPasswordUseCase()
    }

    return ResetPasswordViewModel(
        container: container,
        errorHandler: errorHandler ?? ErrorHandler()
    )
}

/// 이메일 인증까지 완료한 상태의 ViewModel을 만든다.
@MainActor
private func makeVerifiedViewModel(
    resetPasswordUseCase: ResetPasswordUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil,
    email: String = "member@umc.dev"
) async throws -> ResetPasswordViewModel {
    let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
    sendEmailVerificationUseCase.result = .success("verify-id-1")
    let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
    verifyEmailCodeUseCase.result = .success("verify-token-1")

    let viewModel = makeViewModel(
        sendEmailVerificationUseCase: sendEmailVerificationUseCase,
        verifyEmailCodeUseCase: verifyEmailCodeUseCase,
        resetPasswordUseCase: resetPasswordUseCase,
        errorHandler: errorHandler
    )

    viewModel.emailVerificationFlow.email = email
    try await viewModel.emailVerificationFlow.requestEmailVerification()
    try await viewModel.emailVerificationFlow.verifyEmailCode("123456")

    return viewModel
}

// MARK: - Mocks — UseCase
//
// `MockSendEmailVerificationUseCase`/`MockVerifyEmailCodeUseCase`/
// `MockResendEmailVerificationUseCase`는 `Support/MockAuthUseCases.swift`의 공용 Mock을 사용한다 (#956).

private final class MockResetPasswordUseCase: ResetPasswordUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Void, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedEmailVerificationToken: String?
    private(set) var receivedNewPassword: String?

    func execute(emailVerificationToken: String, newPassword: String) async throws {
        callCount += 1
        receivedEmailVerificationToken = emailVerificationToken
        receivedNewPassword = newPassword
        _ = try result.get()
    }
}
