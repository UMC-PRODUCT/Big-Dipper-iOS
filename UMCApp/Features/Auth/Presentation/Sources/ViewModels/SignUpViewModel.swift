import AuthDomain
import CoreDI
import Foundation
import UMCFoundation

/// 소셜 신규회원 가입 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 절대규칙 #1에 따라 `@Observable`을 사용한다. 이메일 인증 발송/검증/재발송 실패
/// (`EmailVerificationError` 등)는 `FormEmailField`가 자체적으로 인라인 표시하므로
/// 그대로 rethrow하고, 그 외(학교/약관 조회 실패, 회원가입 실패)는 `LoginViewModel`과
/// 동일한 패턴(`Loadable` 또는 `ErrorHandler`)으로 처리한다.
@Observable
final class SignUpViewModel {

    // MARK: - Property

    private let oAuthVerificationToken: String
    private let postRegisterLoginContext: PostRegisterLoginContext?

    private let fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol
    private let registerUseCase: RegisterUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let errorHandler: ErrorHandler

    /// 이메일 인증(발송·검증·재전송) 상태와 액션 — `EmailVerificationFlow`에 위임한다.
    var emailVerificationFlow: EmailVerificationFlow

    /// 약관 조회·동의 토글 상태와 액션 — `TermsAgreementFlow`에 위임한다.
    var termsAgreementFlow: TermsAgreementFlow

    /// 사용자 실명
    var name: String

    /// 사용자 닉네임
    var nickname: String

    /// 선택된 학교
    var selectedSchool: School?

    /// 학교 목록 로딩 상태
    private(set) var schoolsState: Loadable<[School]> = .idle

    /// 회원가입 진행 상태 (성공 시 서버 응답 memberId 보관)
    private(set) var registerState: Loadable<String> = .idle

    /// 가입은 성공했으나 세션 복구에 실패해 수동 재로그인이 필요한지 여부
    ///
    /// 서버가 가입 응답에 토큰을 주지 않고 소셜 재로그인마저 실패한 경우
    /// (예: Apple의 1회용 `authorizationCode` 소비)에 `true`가 된다.
    private(set) var requiresManualLoginAfterRegister = false

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        verificationToken: String,
        initialEmail: String? = nil,
        initialFullName: String? = nil,
        postRegisterLoginContext: PostRegisterLoginContext? = nil
    ) {
        self.oAuthVerificationToken = verificationToken
        self.postRegisterLoginContext = postRegisterLoginContext
        self.fetchSignUpDataUseCase = container.resolve(FetchSignUpDataUseCaseProtocol.self)
        self.registerUseCase = container.resolve(RegisterUseCaseProtocol.self)
        self.loginUseCase = container.resolve(LoginUseCaseProtocol.self)
        self.errorHandler = errorHandler

        let trimmedEmail = initialEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.emailVerificationFlow = EmailVerificationFlow(
            purpose: .register,
            initialEmail: trimmedEmail,
            sendEmailVerificationUseCase: container.resolve(
                SendEmailVerificationUseCaseProtocol.self
            ),
            verifyEmailCodeUseCase: container.resolve(VerifyEmailCodeUseCaseProtocol.self),
            resendEmailVerificationUseCase: container.resolve(
                ResendEmailVerificationUseCaseProtocol.self
            )
        )
        self.termsAgreementFlow = TermsAgreementFlow(
            fetchSignUpDataUseCase: self.fetchSignUpDataUseCase
        )
        self.name = initialFullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.nickname = ""
    }

    // MARK: - Computed Property

    /// 폼 유효성 검증 상태 — 필수 약관 동의를 포함한다.
    var isFormValid: Bool {
        !name.isEmpty &&
        !nickname.isEmpty &&
        !emailVerificationFlow.email.isEmpty &&
        selectedSchool != nil &&
        emailVerificationFlow.isEmailVerified &&
        termsAgreementFlow.mandatoryTermsAgreed
    }

    // MARK: - Function (Data Loading)

    /// 학교 목록 조회
    @MainActor
    func fetchSchools() async {
        schoolsState = .loading
        do {
            let schools = try await fetchSignUpDataUseCase.fetchSchools()
            schoolsState = .loaded(schools)
        } catch {
            schoolsState = .failed(AppError.from(error))
        }
    }

    // MARK: - Function (Register)

    /// 회원가입 실행 — 권한 요청 없이 바로 API를 호출한다.
    @MainActor
    func register() async {
        guard !registerState.isLoading else { return }
        guard isFormValid,
              let selectedSchool,
              let emailVerificationToken = emailVerificationFlow.emailVerificationToken else {
            return
        }

        registerState = .loading
        requiresManualLoginAfterRegister = false

        let agreements = termsAgreementFlow.termsAgreements.map {
            TermsAgreement(termsId: $0.key, isAgreed: $0.value)
        }

        do {
            let result = try await registerUseCase.execute(
                oAuthVerificationToken: oAuthVerificationToken,
                name: name,
                nickname: nickname,
                emailVerificationToken: emailVerificationToken,
                schoolId: selectedSchool.id,
                profileImageId: nil,
                termsAgreements: agreements
            )

            if !result.sessionEstablished {
                do {
                    try await restoreSessionAfterRegister()
                } catch {
                    requiresManualLoginAfterRegister = true
                }
            }

            registerState = .loaded(result.memberId)
        } catch {
            registerState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Auth",
                action: "register",
                retryAction: { [weak self] in await self?.register() }
            ))
        }
    }

    // MARK: - Private Function

    /// 가입 직후 서버가 세션 토큰을 발급하지 않은 경우, 가입 직전 사용한 소셜 자격으로
    /// 재로그인해 세션을 복구한다 (레거시 `restoreSessionAfterRegisterIfNeeded` 대응).
    private func restoreSessionAfterRegister() async throws {
        guard let postRegisterLoginContext else {
            throw AuthError.socialLoginFailed(
                provider: "Auth",
                reason: "재로그인에 사용할 소셜 로그인 컨텍스트가 없습니다."
            )
        }

        let result: OAuthLoginResult
        switch postRegisterLoginContext {
        case .kakao(let accessToken, let email):
            result = try await loginUseCase.executeKakao(accessToken: accessToken, email: email)
        case .apple(let authorizationCode, let email, let fullName):
            result = try await loginUseCase.executeApple(
                authorizationCode: authorizationCode,
                email: email,
                fullName: fullName
            )
        case .google(let accessToken):
            result = try await loginUseCase.executeGoogle(accessToken: accessToken)
        }

        guard case .existingMember = result else {
            throw AuthError.socialLoginFailed(
                provider: "Auth",
                reason: "회원가입 후 세션 복구에 실패했습니다."
            )
        }
    }
}
