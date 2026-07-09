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
    private let sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol
    private let verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol
    private let resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol
    private let registerUseCase: RegisterUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let errorHandler: ErrorHandler

    /// 사용자 실명
    var name: String

    /// 사용자 닉네임
    var nickname: String

    /// 이메일 주소
    var email: String

    /// 선택된 학교
    var selectedSchool: School?

    /// 약관 동의 상태 (termsId → 동의 여부)
    var termsAgreements: [String: Bool] = [:]

    /// 학교 목록 로딩 상태
    private(set) var schoolsState: Loadable<[School]> = .idle

    /// 약관 목록 로딩 상태 (서비스·개인정보 2종, marketing 미노출)
    private(set) var termsState: Loadable<[Terms]> = .idle

    /// 이메일 인증 완료 여부 — `FormEmailField`와 양방향 바인딩된다.
    var isEmailVerified: Bool = false

    /// 이메일 인증 발송 후 발급되는 요청 식별자
    private(set) var emailVerificationId: String?

    /// 이메일 인증 코드 검증 완료 후 발급되는 토큰
    private(set) var emailVerificationToken: String?

    /// 마지막으로 검증에 성공한 인증 코드
    private(set) var verificationCode: String = ""

    /// 이메일 변경 감지를 위한 마지막 스냅샷
    private var lastEmailSnapshot: String

    /// 회원가입 진행 상태 (성공 시 서버 응답 memberId 보관)
    private(set) var registerState: Loadable<String> = .idle

    /// 가입은 성공했으나 세션 복구에 실패해 수동 재로그인이 필요한지 여부
    ///
    /// 서버가 가입 응답에 토큰을 주지 않고 소셜 재로그인마저 실패한 경우
    /// (예: Apple의 1회용 `authorizationCode` 소비)에 `true`가 된다.
    private(set) var requiresManualLoginAfterRegister = false

    @ObservationIgnored private var isRequestingEmailVerification = false
    @ObservationIgnored private var isVerifyingEmailCode = false
    @ObservationIgnored private var isResendingEmailVerification = false

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
        self.sendEmailVerificationUseCase = container.resolve(
            SendEmailVerificationUseCaseProtocol.self
        )
        self.verifyEmailCodeUseCase = container.resolve(VerifyEmailCodeUseCaseProtocol.self)
        self.resendEmailVerificationUseCase = container.resolve(
            ResendEmailVerificationUseCaseProtocol.self
        )
        self.registerUseCase = container.resolve(RegisterUseCaseProtocol.self)
        self.loginUseCase = container.resolve(LoginUseCaseProtocol.self)
        self.errorHandler = errorHandler

        let trimmedEmail = initialEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.email = trimmedEmail
        self.lastEmailSnapshot = trimmedEmail
        self.name = initialFullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.nickname = ""
    }

    // MARK: - Computed Property

    /// 폼 유효성 검증 상태 — 필수 약관 동의를 포함한다.
    ///
    /// 약관이 아직 로딩되지 않았다면(`termsState != .loaded`) `mandatoryTermsAgreed`가
    /// 항상 `false`이므로 제출이 자동으로 차단된다. 하드코딩된 termsId fallback은 두지 않는다.
    var isFormValid: Bool {
        !name.isEmpty &&
        !nickname.isEmpty &&
        !email.isEmpty &&
        selectedSchool != nil &&
        isEmailVerified &&
        mandatoryTermsAgreed
    }

    /// 전체 약관 동의 여부
    var isAllTermsAgreed: Bool {
        !termsAgreements.isEmpty && termsAgreements.values.allSatisfy { $0 }
    }

    /// 필수 약관 모두 동의 여부
    private var mandatoryTermsAgreed: Bool {
        guard case .loaded(let terms) = termsState else { return false }
        return terms
            .filter(\.isMandatory)
            .allSatisfy { termsAgreements[$0.id] == true }
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
            schoolsState = .failed(mapToAppError(error))
        }
    }

    /// 약관 목록 조회 (SERVICE, PRIVACY — marketing은 미노출)
    @MainActor
    func fetchTerms() async {
        termsState = .loading
        do {
            var terms: [Terms] = []
            for type in [TermsType.service, TermsType.privacy] {
                let term = try await fetchSignUpDataUseCase.fetchTerms(type: type)
                terms.append(term)
                termsAgreements[term.id] = false
            }
            termsState = .loaded(terms)
        } catch {
            termsState = .failed(mapToAppError(error))
        }
    }

    // MARK: - Function (Email Verification)

    /// 이메일 인증번호 발송 요청.
    ///
    /// `FormEmailField`가 bare `Task {}`로 호출하므로 중복 탭에 대비해 재진입을 막는다.
    @MainActor
    func requestEmailVerification() async throws {
        guard !isRequestingEmailVerification else { return }
        isRequestingEmailVerification = true
        defer { isRequestingEmailVerification = false }

        let id = try await sendEmailVerificationUseCase.execute(email: email, purpose: .register)
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
        verificationCode = code
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
        verificationCode = ""
    }

    // MARK: - Function (Terms)

    /// 전체 약관 동의/해제 토글
    func toggleAllTerms(_ agreed: Bool) {
        termsAgreements = termsAgreements.mapValues { _ in agreed }
    }

    /// 개별 약관 동의 토글
    func toggleTerm(_ termsId: String) {
        termsAgreements[termsId, default: false].toggle()
    }

    // MARK: - Function (Register)

    /// 회원가입 실행 — 권한 요청 없이 바로 API를 호출한다.
    @MainActor
    func register() async {
        guard !registerState.isLoading else { return }
        guard isFormValid,
              let selectedSchool,
              let emailVerificationToken else {
            return
        }

        registerState = .loading
        requiresManualLoginAfterRegister = false

        let agreements = termsAgreements.map {
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

    /// `RepositoryError`/`NetworkError`/`AuthError`를 `AppError`로 통일해 `Loadable.failed`에 담는다.
    private func mapToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if let repositoryError = error as? RepositoryError {
            return .repository(repositoryError)
        }
        if let networkError = error as? NetworkError {
            return .network(networkError)
        }
        if let authError = error as? AuthError {
            return .auth(authError)
        }
        return .unknown(message: error.localizedDescription)
    }
}
