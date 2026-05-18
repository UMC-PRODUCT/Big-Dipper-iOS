//
//  ResetPasswordViewModel.swift
//  AppProduct
//

import Foundation

/// 비밀번호 찾기 화면의 상태와 로직을 관리하는 ViewModel
///
/// 흐름: 이메일 입력 → 인증코드 입력 → 새 비밀번호 입력 → 변경 완료
/// `purpose=PASSWORD_RESET`으로 발급된 `emailVerificationToken`만 사용합니다.
@Observable
@MainActor
final class ResetPasswordViewModel {

    // MARK: - Property

    private let sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol
    private let resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol
    private let verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol
    private let resetPasswordUseCase: ResetPasswordUseCaseProtocol

    /// 이메일 입력
    var emailInput: String = ""
    /// 새 비밀번호 입력
    var newPasswordInput: String = ""
    /// 새 비밀번호 확인 입력
    var newPasswordConfirmInput: String = ""

    private(set) var emailVerificationId: String?
    private(set) var emailVerificationToken: String?
    private(set) var isEmailVerified: Bool = false

    /// 비밀번호 변경 결과
    private(set) var resetState: Loadable<Bool> = .idle

    // MARK: - Init

    init(
        sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
        resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol,
        verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
        resetPasswordUseCase: ResetPasswordUseCaseProtocol
    ) {
        self.sendEmailVerificationUseCase = sendEmailVerificationUseCase
        self.resendEmailVerificationUseCase = resendEmailVerificationUseCase
        self.verifyEmailCodeUseCase = verifyEmailCodeUseCase
        self.resetPasswordUseCase = resetPasswordUseCase
    }

    // MARK: - Validation

    /// 새 비밀번호 8자 이상 검증
    var isPasswordValid: Bool {
        newPasswordInput.count >= 8
    }

    /// 비밀번호 확인 일치 검증
    var isPasswordConfirmed: Bool {
        !newPasswordInput.isEmpty &&
        newPasswordInput == newPasswordConfirmInput
    }

    /// 비밀번호 변경 버튼 활성 조건
    var canSubmit: Bool {
        isEmailVerified &&
        emailVerificationToken != nil &&
        isPasswordValid &&
        isPasswordConfirmed
    }

    // MARK: - Function

    /// 이메일 인증번호 요청 (purpose=PASSWORD_RESET)
    func requestEmailVerification() async throws {
        let id = try await sendEmailVerificationUseCase
            .execute(email: emailInput, purpose: .passwordReset)
        emailVerificationId = id
    }

    /// 이메일 인증번호 재전송
    func resendEmailVerification() async throws {
        guard let emailVerificationId else {
            try await requestEmailVerification()
            return
        }
        try await resendEmailVerificationUseCase.execute(
            emailVerificationId: emailVerificationId
        )
    }

    /// 이메일 인증코드 검증
    func verifyEmailCode(_ code: String) async throws {
        guard let emailVerificationId else { return }
        let token = try await verifyEmailCodeUseCase.execute(
            emailVerificationId: emailVerificationId,
            verificationCode: code
        )
        emailVerificationToken = token
        isEmailVerified = true
    }

    /// 이메일 변경 시 인증 상태 초기화
    func resetEmailVerification() {
        isEmailVerified = false
        emailVerificationId = nil
        emailVerificationToken = nil
    }

    /// 비밀번호 변경 실행
    func resetPassword() async {
        guard canSubmit, let emailVerificationToken else { return }
        resetState = .loading
        do {
            try await resetPasswordUseCase.execute(
                emailVerificationToken: emailVerificationToken,
                newPassword: newPasswordInput
            )
            resetState = .loaded(true)
        } catch let error as AppError {
            resetState = .failed(error)
        } catch let error as AuthError {
            resetState = .failed(.auth(error))
        } catch let error as RepositoryError {
            resetState = .failed(.repository(error))
        } catch let error as NetworkError {
            resetState = .failed(.network(error))
        } catch {
            resetState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }
}
