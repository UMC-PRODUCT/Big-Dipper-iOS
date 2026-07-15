//
//  ResetPasswordViewModel.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/10/26.
//

import AuthDomain
import CoreDI
import Foundation
import UMCFoundation

/// 비밀번호 재설정 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 절대규칙 #1에 따라 `@Observable`을 사용한다. 흐름: 이메일 인증(`PASSWORD_RESET` 목적) →
/// 새 비밀번호 입력 → 재설정 요청. 이메일 인증 처리(재진입 방지, 이메일 변경 시 인증 상태 리셋)는
/// `SignUpByIdPwViewModel`과 공유하는 `EmailVerificationFlow`에 위임하며, 재설정 실패는
/// 흐름 중단형 에러이므로 `SignUpByIdPwViewModel.register()`와 동일하게 `ErrorHandler`로 처리한다.
@Observable
final class ResetPasswordViewModel {

    // MARK: - Constant

    private enum Constants {
        static let minimumPasswordLength: Int = 8
    }

    // MARK: - Property

    private let resetPasswordUseCase: ResetPasswordUseCaseProtocol
    private let errorHandler: ErrorHandler

    /// 이메일 인증(발송·검증·재전송) 상태와 액션 — `EmailVerificationFlow`에 위임한다.
    var emailVerificationFlow: EmailVerificationFlow

    /// 새 비밀번호
    var newPassword: String = ""

    /// 새 비밀번호 확인
    var newPasswordConfirm: String = ""

    /// 비밀번호 재설정 진행 상태
    private(set) var resetPasswordState: Loadable<Bool> = .idle

    // MARK: - Init

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.resetPasswordUseCase = container.resolve(ResetPasswordUseCaseProtocol.self)
        self.errorHandler = errorHandler
        self.emailVerificationFlow = EmailVerificationFlow(
            purpose: .passwordReset,
            sendEmailVerificationUseCase: container.resolve(
                SendEmailVerificationUseCaseProtocol.self
            ),
            verifyEmailCodeUseCase: container.resolve(VerifyEmailCodeUseCaseProtocol.self),
            resendEmailVerificationUseCase: container.resolve(
                ResendEmailVerificationUseCaseProtocol.self
            )
        )
    }

    // MARK: - Computed Property

    /// 새 비밀번호 최소 길이(8자) 충족 여부
    var isPasswordValid: Bool {
        newPassword.count >= Constants.minimumPasswordLength
    }

    /// 새 비밀번호 확인 일치 여부
    var isPasswordConfirmed: Bool {
        !newPasswordConfirm.isEmpty && newPassword == newPasswordConfirm
    }

    /// 재설정 제출 가능 여부
    var canSubmit: Bool {
        emailVerificationFlow.isEmailVerified &&
        emailVerificationFlow.emailVerificationToken != nil &&
        isPasswordValid &&
        isPasswordConfirmed
    }

    // MARK: - Function (Reset Password)

    /// 비밀번호 재설정 실행
    @MainActor
    func resetPassword() async {
        guard !resetPasswordState.isLoading else { return }
        guard canSubmit,
              let emailVerificationToken = emailVerificationFlow.emailVerificationToken else {
            return
        }

        resetPasswordState = .loading

        do {
            try await resetPasswordUseCase.execute(
                emailVerificationToken: emailVerificationToken,
                newPassword: newPassword
            )
            resetPasswordState = .loaded(true)
        } catch {
            resetPasswordState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Auth",
                action: "resetPassword",
                retryAction: { [weak self] in await self?.resetPassword() }
            ))
        }
    }
}
