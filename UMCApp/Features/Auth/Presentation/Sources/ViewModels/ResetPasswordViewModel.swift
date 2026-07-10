import AuthDomain
import CoreDI
import Foundation
import UMCFoundation

/// 비밀번호 재설정 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 절대규칙 #1에 따라 `@Observable`을 사용한다. 흐름: 이메일 인증(`PASSWORD_RESET` 목적) →
/// 새 비밀번호 입력 → 재설정 요청. `SignUpByIdPwViewModel`과 이메일 인증 처리 패턴(재진입 방지,
/// 이메일 변경 시 인증 상태 리셋)을 공유하며, 재설정 실패는 흐름 중단형 에러이므로
/// `SignUpByIdPwViewModel.register()`와 동일하게 `ErrorHandler`로 처리한다.
@Observable
final class ResetPasswordViewModel {

    // MARK: - Constant

    private enum Constants {
        static let minimumPasswordLength: Int = 8
    }

    // MARK: - Property

    private let sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol
    private let verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol
    private let resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol
    private let resetPasswordUseCase: ResetPasswordUseCaseProtocol
    private let errorHandler: ErrorHandler

    /// 이메일 주소
    var email: String = ""

    /// 새 비밀번호
    var newPassword: String = ""

    /// 새 비밀번호 확인
    var newPasswordConfirm: String = ""

    /// 이메일 인증 완료 여부 — `FormEmailField`와 양방향 바인딩된다.
    var isEmailVerified: Bool = false

    /// 이메일 인증 발송 후 발급되는 요청 식별자
    private(set) var emailVerificationId: String?

    /// 이메일 인증 코드 검증 완료 후 발급되는 토큰
    private(set) var emailVerificationToken: String?

    /// 비밀번호 재설정 진행 상태
    private(set) var resetPasswordState: Loadable<Bool> = .idle

    /// 이메일 변경 감지를 위한 마지막 스냅샷
    private var lastEmailSnapshot: String = ""

    @ObservationIgnored private var isRequestingEmailVerification = false
    @ObservationIgnored private var isVerifyingEmailCode = false
    @ObservationIgnored private var isResendingEmailVerification = false

    // MARK: - Init

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.sendEmailVerificationUseCase = container.resolve(
            SendEmailVerificationUseCaseProtocol.self
        )
        self.verifyEmailCodeUseCase = container.resolve(VerifyEmailCodeUseCaseProtocol.self)
        self.resendEmailVerificationUseCase = container.resolve(
            ResendEmailVerificationUseCaseProtocol.self
        )
        self.resetPasswordUseCase = container.resolve(ResetPasswordUseCaseProtocol.self)
        self.errorHandler = errorHandler
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
        isEmailVerified &&
        emailVerificationToken != nil &&
        isPasswordValid &&
        isPasswordConfirmed
    }

    // MARK: - Function (Email Verification)

    /// 이메일 인증번호 발송 요청 (`purpose: .passwordReset`).
    ///
    /// `FormEmailField`가 bare `Task {}`로 호출하므로 중복 탭에 대비해 재진입을 막는다.
    @MainActor
    func requestEmailVerification() async throws {
        guard !isRequestingEmailVerification else { return }
        isRequestingEmailVerification = true
        defer { isRequestingEmailVerification = false }

        let id = try await sendEmailVerificationUseCase.execute(
            email: email,
            purpose: .passwordReset
        )
        emailVerificationId = id
    }

    /// 이메일 인증번호 검증
    @MainActor
    func verifyEmailCode(_ code: String) async throws {
        guard !isVerifyingEmailCode else { return }
        guard let emailVerificationId else { return }
        isVerifyingEmailCode = true
        defer { isVerifyingEmailCode = false }

        let token = try await verifyEmailCodeUseCase.execute(
            emailVerificationId: emailVerificationId,
            verificationCode: code
        )
        emailVerificationToken = token
        isEmailVerified = true
    }

    /// 이메일 인증번호 재전송
    @MainActor
    func resendEmailVerification() async throws {
        guard !isResendingEmailVerification else { return }
        guard let emailVerificationId else { return }
        isResendingEmailVerification = true
        defer { isResendingEmailVerification = false }

        try await resendEmailVerificationUseCase.execute(emailVerificationId: emailVerificationId)
    }

    /// 이메일 텍스트 변경 콜백 — 실제로 값이 바뀐 경우에만 인증 상태를 리셋한다.
    @MainActor
    func handleEmailChanged() {
        guard email != lastEmailSnapshot else { return }
        lastEmailSnapshot = email
        resetEmailVerification()
    }

    /// 이메일 변경 시 이메일 인증 상태를 초기화한다.
    ///
    /// 기존 인증번호/토큰은 이전 이메일 기준이므로 폐기되어야 한다.
    @MainActor
    func resetEmailVerification() {
        isEmailVerified = false
        emailVerificationId = nil
        emailVerificationToken = nil
    }

    // MARK: - Function (Reset Password)

    /// 비밀번호 재설정 실행
    @MainActor
    func resetPassword() async {
        guard !resetPasswordState.isLoading else { return }
        guard canSubmit, let emailVerificationToken else { return }

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
