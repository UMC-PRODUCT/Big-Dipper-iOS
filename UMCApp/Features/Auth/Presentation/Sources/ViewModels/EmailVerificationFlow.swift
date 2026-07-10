import AuthDomain
import CoreDI
import Foundation

/// 이메일 인증(발송 → 검증 → 재전송) 흐름을 캡슐화한 컴포지션 객체.
///
/// `SignUpByIdPwViewModel`과 `ResetPasswordViewModel`이 동일한 이메일 인증 상태·재진입 가드·
/// 이메일 변경 감지 로직을 복사-붙여넣기로 중복 보유하던 것을 이 타입으로 추출했다. 두 ViewModel은
/// 이 객체를 프로퍼티로 보유하고 위임하며, `purpose`(가입/비밀번호 재설정)만 초기화 시점에 다르게
/// 주입한다.
///
/// - Important: 부모 `@Observable` ViewModel에서 `var emailVerificationFlow: EmailVerificationFlow`로
///   선언해야 한다(`let` 금지). `Binding`의 `subscript(dynamicMember:)`는 체인의 모든 단계가
///   `WritableKeyPath`여야 동작하는데, `let` 프로퍼티는 `KeyPath`(읽기 전용)만 만들어
///   `$viewModel.emailVerificationFlow.email` 같은 중첩 바인딩이 깨진다.
@Observable
final class EmailVerificationFlow {

    // MARK: - Property

    private let purpose: EmailVerificationPurpose
    private let sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol
    private let verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol
    private let resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol

    /// 이메일 주소 — `FormEmailField`와 양방향 바인딩된다.
    var email: String = ""

    /// 이메일 인증 완료 여부 — `FormEmailField`와 양방향 바인딩된다.
    var isEmailVerified: Bool = false

    /// 이메일 인증 발송 후 발급되는 요청 식별자
    private(set) var emailVerificationId: String?

    /// 이메일 인증 코드 검증 완료 후 발급되는 토큰
    private(set) var emailVerificationToken: String?

    /// 이메일 변경 감지를 위한 마지막 스냅샷
    private var lastEmailSnapshot: String = ""

    /// `resetEmailVerification()` 완료 시점에 호출되는 확장 지점.
    ///
    /// 이 흐름을 보유한 ViewModel이 이메일 인증과 함께 리셋되어야 하는 자신만의 파생 상태
    /// (예: `SignUpByIdPwViewModel`의 이메일 중복 확인 상태)를 가지고 있을 때 사용한다.
    /// 별도 파생 상태가 없는 경우(`ResetPasswordViewModel`)는 설정하지 않아도 된다.
    @ObservationIgnored var onReset: (@MainActor () -> Void)?

    @ObservationIgnored private var isRequestingEmailVerification = false
    @ObservationIgnored private var isVerifyingEmailCode = false
    @ObservationIgnored private var isResendingEmailVerification = false

    // MARK: - Init

    init(
        purpose: EmailVerificationPurpose,
        sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
        verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
        resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol
    ) {
        self.purpose = purpose
        self.sendEmailVerificationUseCase = sendEmailVerificationUseCase
        self.verifyEmailCodeUseCase = verifyEmailCodeUseCase
        self.resendEmailVerificationUseCase = resendEmailVerificationUseCase
    }

    // MARK: - Function

    /// 이메일 인증번호 발송 요청.
    ///
    /// `FormEmailField`가 bare `Task {}`로 호출하므로 중복 탭에 대비해 재진입을 막는다.
    @MainActor
    func requestEmailVerification() async throws {
        guard !isRequestingEmailVerification else { return }
        isRequestingEmailVerification = true
        defer { isRequestingEmailVerification = false }

        let id = try await sendEmailVerificationUseCase.execute(email: email, purpose: purpose)
        emailVerificationId = id
    }

    /// 이메일 인증번호 검증.
    ///
    /// - Returns: 검증이 실제로 수행되어 `isEmailVerified`가 갱신됐으면 `true`, 재진입 가드나
    ///   `emailVerificationId` 부재로 스킵됐으면 `false`. 호출자가 검증 성공 시에만 추가 동작
    ///   (예: 이메일 중복 확인 예약)을 트리거할 수 있도록 반환하되, 별도 동작이 필요 없는
    ///   호출자는 결과를 버려도 된다.
    @discardableResult
    @MainActor
    func verifyEmailCode(_ code: String) async throws -> Bool {
        guard !isVerifyingEmailCode else { return false }
        guard let emailVerificationId else { return false }
        isVerifyingEmailCode = true
        defer { isVerifyingEmailCode = false }

        let token = try await verifyEmailCodeUseCase.execute(
            emailVerificationId: emailVerificationId,
            verificationCode: code
        )
        emailVerificationToken = token
        isEmailVerified = true
        return true
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

    /// 이메일 변경 시 이메일 인증 상태를 초기화하고 `onReset` 훅을 호출한다.
    ///
    /// 기존 인증번호/토큰은 이전 이메일 기준이므로 폐기되어야 한다.
    @MainActor
    func resetEmailVerification() {
        isEmailVerified = false
        emailVerificationId = nil
        emailVerificationToken = nil
        onReset?()
    }
}
