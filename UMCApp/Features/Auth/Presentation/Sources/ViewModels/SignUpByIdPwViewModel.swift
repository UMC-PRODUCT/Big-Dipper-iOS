import AuthDomain
import CoreDI
import Foundation
import UMCFoundation

/// 이메일(ID/PW) 신규회원 가입 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 절대규칙 #1에 따라 `@Observable`을 사용한다. `SignUpViewModel`(소셜)과 대부분의 흐름을
/// 공유하되, 비밀번호 검증과 이메일 인증 완료 이후의 중복 확인(debounce) 로직이 추가된다.
@Observable
final class SignUpByIdPwViewModel {

    // MARK: - Constant

    private enum Constants {
        static let emailAvailabilityDebounceMilliseconds: Int64 = 500
        static let minimumPasswordLength: Int = 8
    }

    // MARK: - Property

    private let fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol
    private let checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol
    private let registerByEmailUseCase: RegisterByEmailUseCaseProtocol
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    private let errorHandler: ErrorHandler

    /// debounce 대기를 담당하는 sleeper. 운영 기본값은 `Task.sleep`이며, 테스트는 결정적으로
    /// 즉시 반환되는 sleeper를 주입해 wall-clock 대기 없이 debounce 취소 로직을 검증한다.
    private let emailAvailabilityDebounceSleep: @Sendable (Duration) async throws -> Void

    /// 이메일 인증(발송·검증·재전송) 상태와 액션 — `EmailVerificationFlow`에 위임한다.
    var emailVerificationFlow: EmailVerificationFlow

    /// 약관 조회·동의 토글 상태와 액션 — `TermsAgreementFlow`에 위임한다.
    var termsAgreementFlow: TermsAgreementFlow

    /// 사용자 실명
    var name: String = ""

    /// 사용자 닉네임
    var nickname: String = ""

    /// 비밀번호
    var password: String = ""

    /// 비밀번호 확인
    var passwordConfirm: String = ""

    /// 선택된 학교
    var selectedSchool: School?

    /// 학교 목록 로딩 상태
    private(set) var schoolsState: Loadable<[School]> = .idle

    /// 마지막으로 검증에 성공한 인증 코드
    private(set) var verificationCode: String = ""

    /// 이메일 인증 완료 후 진행되는 이메일 중복 확인 상태
    private(set) var emailAvailabilityState: Loadable<Bool> = .idle

    /// 회원가입 진행 상태 (성공 시 서버 응답 memberId 보관)
    private(set) var registerState: Loadable<String> = .idle

    /// 가입 성공 후 재조회한 프로필이 승인된 상태인지 여부.
    ///
    /// `registerState`가 `.loaded`로 바뀐 시점에는 항상 확정되어 있으며, View는 이 값으로
    /// `showMain()`/`showLogin()` 분기를 결정한다.
    private(set) var isApprovedAfterRegister = false

    /// 이메일 중복 확인 debounce/실행을 담당하는 진행 중인 Task.
    ///
    /// setter는 `private`지만, getter는 모듈 기본(`internal`) 접근 수준을 유지해
    /// `@testable import AuthPresentation`에서 `await emailAvailabilityTask?.value`로
    /// 대기함으로써 wall-clock 없이 결정적으로 debounce 완료 시점을 테스트할 수 있게 한다.
    @ObservationIgnored private(set) var emailAvailabilityTask: Task<Void, Never>?

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        emailAvailabilityDebounceSleep: @escaping @Sendable (Duration) async throws -> Void = {
            duration in try await Task.sleep(for: duration)
        }
    ) {
        self.fetchSignUpDataUseCase = container.resolve(FetchSignUpDataUseCaseProtocol.self)
        self.checkEmailAvailabilityUseCase = container.resolve(
            CheckEmailAvailabilityUseCaseProtocol.self
        )
        self.registerByEmailUseCase = container.resolve(RegisterByEmailUseCaseProtocol.self)
        self.fetchMyProfileUseCase = container.resolve(FetchMyProfileUseCaseProtocol.self)
        self.errorHandler = errorHandler
        self.emailAvailabilityDebounceSleep = emailAvailabilityDebounceSleep
        self.emailVerificationFlow = EmailVerificationFlow(
            purpose: .register,
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
        self.emailVerificationFlow.onReset = { [weak self] in
            self?.resetEmailAvailability()
        }
    }

    // MARK: - Computed Property

    /// 비밀번호 최소 길이(8자) 충족 여부
    var isPasswordValid: Bool {
        password.count >= Constants.minimumPasswordLength
    }

    /// 비밀번호 확인 일치 여부
    var isPasswordConfirmed: Bool {
        !passwordConfirm.isEmpty && password == passwordConfirm
    }

    /// 이메일 중복 확인 결과 (사용 가능하면 `true`)
    private var isEmailAvailable: Bool {
        emailAvailabilityState.value == true
    }

    /// 최종 제출 가능 여부 — 필수 약관 동의와 이메일 중복 확인 통과를 포함한다.
    ///
    /// 약관이 아직 로딩되지 않았다면(`termsAgreementFlow.termsState != .loaded`)
    /// `mandatoryTermsAgreed`가 항상 `false`이므로 제출이 자동으로 차단된다.
    /// 하드코딩된 termsId fallback은 두지 않는다.
    var canSubmit: Bool {
        !name.isEmpty &&
        !nickname.isEmpty &&
        !emailVerificationFlow.email.isEmpty &&
        isPasswordValid &&
        isPasswordConfirmed &&
        selectedSchool != nil &&
        emailVerificationFlow.isEmailVerified &&
        isEmailAvailable &&
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

    // MARK: - Function (Email Verification)

    /// 이메일 인증번호 검증. 성공 시 이메일 중복 확인을 이어서 예약한다.
    ///
    /// 공통 흐름(`EmailVerificationFlow`)에 위임하되, 검증이 실제로 완료된 경우에만 이 화면
    /// 전용 파생 동작(이메일 중복 확인 예약)을 수행한다.
    @MainActor
    func verifyEmailCode(_ code: String) async throws {
        guard try await emailVerificationFlow.verifyEmailCode(code) else { return }
        verificationCode = code
        scheduleEmailAvailabilityCheck()
    }

    // MARK: - Function (Email Availability)

    /// 이메일 중복 확인을 500ms 디바운스 후 예약한다.
    ///
    /// 연속 호출(예: 인증 재시도) 시 이전 예약을 취소하고 마지막 1회만 실제로 실행되도록
    /// `emailAvailabilityTask`를 매번 새 Task로 교체한다 (레거시 `scheduleEmailAvailabilityCheck`
    /// 이식, 취소 안전).
    @MainActor
    private func scheduleEmailAvailabilityCheck() {
        emailAvailabilityTask?.cancel()
        let targetEmail = emailVerificationFlow.email
        let sleep = emailAvailabilityDebounceSleep
        emailAvailabilityTask = Task { [weak self] in
            try? await sleep(.milliseconds(Constants.emailAvailabilityDebounceMilliseconds))
            guard !Task.isCancelled else { return }
            await self?.performEmailAvailabilityCheck(email: targetEmail)
        }
    }

    /// 이메일 중복 확인 실패 후 사용자가 명시적으로 요청한 즉시 재시도.
    ///
    /// 사용자가 직접 재시도를 요청한 액션이므로 debounce 없이 바로 확인을 수행한다.
    @MainActor
    func retryEmailAvailabilityCheck() {
        guard case .failed = emailAvailabilityState else { return }
        emailAvailabilityTask?.cancel()
        let targetEmail = emailVerificationFlow.email
        emailAvailabilityTask = Task { [weak self] in
            await self?.performEmailAvailabilityCheck(email: targetEmail)
        }
    }

    @MainActor
    private func performEmailAvailabilityCheck(email: String) async {
        guard !Task.isCancelled else { return }
        emailAvailabilityState = .loading
        do {
            let isAvailable = try await checkEmailAvailabilityUseCase.execute(email: email)
            guard !Task.isCancelled else { return }
            emailAvailabilityState = .loaded(isAvailable)
        } catch {
            guard !Task.isCancelled else { return }
            emailAvailabilityState = .failed(AppError.from(error))
        }
    }

    /// 이메일 인증 상태가 리셋될 때(이메일 변경) 이메일 중복 확인 관련 파생 상태도 초기화한다.
    ///
    /// `EmailVerificationFlow.onReset` 훅으로 연결된다.
    @MainActor
    private func resetEmailAvailability() {
        verificationCode = ""
        emailAvailabilityTask?.cancel()
        emailAvailabilityTask = nil
        emailAvailabilityState = .idle
    }

    // MARK: - Function (Register)

    /// 회원가입 실행 — 성공 시 프로필을 재조회해 승인 여부를 확정한다.
    @MainActor
    func register() async {
        guard !registerState.isLoading else { return }
        guard canSubmit,
              let selectedSchool,
              let emailVerificationToken = emailVerificationFlow.emailVerificationToken else {
            return
        }

        registerState = .loading

        let agreements = termsAgreementFlow.termsAgreements.map {
            TermsAgreement(termsId: $0.key, isAgreed: $0.value)
        }

        do {
            let result = try await registerByEmailUseCase.execute(
                rawPassword: password,
                name: name,
                nickname: nickname,
                emailVerificationToken: emailVerificationToken,
                schoolId: selectedSchool.id,
                termsAgreements: agreements
            )

            isApprovedAfterRegister = await resolveApprovalStatus()
            registerState = .loaded(result.memberId)
        } catch {
            registerState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Auth",
                action: "registerByEmail",
                retryAction: { [weak self] in await self?.register() }
            ))
        }
    }

    // MARK: - Private Function

    /// 가입 직후 프로필을 재조회해 승인 여부(`Profile.isApproved`)를 확정한다.
    ///
    /// 재조회 자체가 실패해도 가입은 이미 완료된 상태이므로 회원가입 실패로 취급하지 않고,
    /// 승인 대기(미승인)로 안전하게 폴백한다.
    private func resolveApprovalStatus() async -> Bool {
        do {
            let profile = try await fetchMyProfileUseCase.execute()
            return profile.isApproved
        } catch {
            return false
        }
    }
}
