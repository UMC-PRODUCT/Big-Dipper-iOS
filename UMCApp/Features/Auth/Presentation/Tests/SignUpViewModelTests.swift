import Testing
import Foundation
import CoreDI
import AuthDomain
import UMCFoundation
@testable import AuthPresentation

@MainActor
@Suite("SignUpViewModel — 폼 검증")
struct SignUpViewModelFormValidationTests {

    @Test("초기 상태는 idle이며 폼은 유효하지 않다")
    func initialStateIsIdle() {
        let viewModel = makeViewModel()
        #expect(viewModel.schoolsState == .idle)
        #expect(viewModel.termsState == .idle)
        #expect(viewModel.registerState == .idle)
        #expect(viewModel.isFormValid == false)
    }

    @Test("이름/닉네임/이메일/학교/이메일인증/필수약관 모두 충족 시 폼이 유효하다")
    func allFieldsFilledMakesFormValid() async throws {
        let viewModel = try await makeValidFormViewModel()
        #expect(viewModel.isFormValid == true)
    }

    @Test("필수 약관 중 하나라도 미동의면 폼이 유효하지 않다")
    func mandatoryTermDisagreementMakesFormInvalid() async throws {
        let viewModel = try await makeValidFormViewModel()
        #expect(viewModel.isFormValid == true)

        viewModel.termsAgreements["terms-privacy"] = false

        #expect(viewModel.isFormValid == false)
    }

    @Test("약관이 아직 로딩되지 않았다면 다른 값이 채워져도 폼이 유효하지 않다")
    func termsNotLoadedMakesFormInvalid() async throws {
        let fetchSignUpDataUseCase = MockFetchSignUpDataUseCase()
        fetchSignUpDataUseCase.fetchSchoolsResult = .success([School(id: "1", name: "테스트대학교")])
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token")

        let viewModel = makeViewModel(
            fetchSignUpDataUseCase: fetchSignUpDataUseCase,
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase
        )
        await viewModel.fetchSchools()
        // fetchTerms()를 호출하지 않아 termsState == .idle을 유지한다.

        viewModel.name = "홍길동"
        viewModel.nickname = "길동이"
        viewModel.email = "member@umc.dev"
        viewModel.selectedSchool = School(id: "1", name: "테스트대학교")
        try await viewModel.requestEmailVerification()
        try await viewModel.verifyEmailCode("123456")

        #expect(viewModel.isFormValid == false)
    }
}

@MainActor
@Suite("SignUpViewModel — 이메일 인증")
struct SignUpViewModelEmailVerificationTests {

    @Test("인증번호 발송 성공 → emailVerificationId 저장, isEmailVerified는 유지")
    func requestVerificationSuccessStoresId() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let viewModel = makeViewModel(sendEmailVerificationUseCase: sendEmailVerificationUseCase)
        viewModel.email = "member@umc.dev"

        try await viewModel.requestEmailVerification()

        #expect(viewModel.emailVerificationId == "verify-id-1")
        #expect(viewModel.isEmailVerified == false)
        #expect(sendEmailVerificationUseCase.callCount == 1)
        #expect(sendEmailVerificationUseCase.receivedEmail == "member@umc.dev")
        #expect(sendEmailVerificationUseCase.receivedPurpose == .register)
    }

    @Test("인증번호 발송 실패 → 에러 rethrow, 상태 변화 없음")
    func requestVerificationFailureRethrows() async {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .failure(EmailVerificationError.emailAlreadyExists)
        let viewModel = makeViewModel(sendEmailVerificationUseCase: sendEmailVerificationUseCase)
        viewModel.email = "member@umc.dev"

        do {
            try await viewModel.requestEmailVerification()
            Issue.record("에러가 발생해야 합니다")
        } catch {
            #expect(error as? EmailVerificationError == .emailAlreadyExists)
        }
        #expect(viewModel.emailVerificationId == nil)
    }

    @Test("인증번호 검증 성공 → isEmailVerified true, 토큰/코드 저장")
    func verifyCodeSuccessSetsVerified() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token-1")
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase
        )
        viewModel.email = "member@umc.dev"
        try await viewModel.requestEmailVerification()

        try await viewModel.verifyEmailCode("654321")

        #expect(viewModel.isEmailVerified == true)
        #expect(viewModel.verificationCode == "654321")
        #expect(verifyEmailCodeUseCase.callCount == 1)
        #expect(verifyEmailCodeUseCase.receivedCode == "654321")
    }

    @Test("인증번호 검증 실패 → isEmailVerified false 유지")
    func verifyCodeFailureKeepsUnverified() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .failure(AuthError.invalidVerificationCode)
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase
        )
        viewModel.email = "member@umc.dev"
        try await viewModel.requestEmailVerification()

        do {
            try await viewModel.verifyEmailCode("000000")
            Issue.record("에러가 발생해야 합니다")
        } catch {
            #expect(error as? AuthError == .invalidVerificationCode)
        }
        #expect(viewModel.isEmailVerified == false)
    }

    @Test("발송 요청 없이 검증을 시도하면 아무 것도 하지 않는다")
    func verifyCodeWithoutRequestIsNoOp() async throws {
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        let viewModel = makeViewModel(verifyEmailCodeUseCase: verifyEmailCodeUseCase)

        try await viewModel.verifyEmailCode("123456")

        #expect(verifyEmailCodeUseCase.callCount == 0)
        #expect(viewModel.isEmailVerified == false)
    }

    @Test("인증번호 재전송 성공/실패가 그대로 반영된다")
    func resendVerificationReflectsResult() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let resendEmailVerificationUseCase = MockResendEmailVerificationUseCase()
        resendEmailVerificationUseCase.result = .success(())
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            resendEmailVerificationUseCase: resendEmailVerificationUseCase
        )
        viewModel.email = "member@umc.dev"
        try await viewModel.requestEmailVerification()

        try await viewModel.resendEmailVerification()
        #expect(resendEmailVerificationUseCase.callCount == 1)

        resendEmailVerificationUseCase.result = .failure(EmailVerificationError.throttled)
        do {
            try await viewModel.resendEmailVerification()
            Issue.record("에러가 발생해야 합니다")
        } catch {
            #expect(error as? EmailVerificationError == .throttled)
        }
        #expect(resendEmailVerificationUseCase.callCount == 2)
    }

    @Test("이메일이 실제로 변경되면 인증 상태가 초기화된다")
    func emailChangeResetsVerification() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token-1")
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase
        )
        viewModel.email = "first@umc.dev"
        try await viewModel.requestEmailVerification()
        try await viewModel.verifyEmailCode("111111")
        #expect(viewModel.isEmailVerified == true)

        viewModel.email = "second@umc.dev"
        viewModel.handleEmailChanged()

        #expect(viewModel.isEmailVerified == false)
        #expect(viewModel.emailVerificationId == nil)
        #expect(viewModel.emailVerificationToken == nil)
        #expect(viewModel.verificationCode == "")
    }

    @Test("이메일 값이 그대로면 인증 상태를 유지한다")
    func sameEmailKeepsVerification() async throws {
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token-1")
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase,
            initialEmail: "same@umc.dev"
        )
        viewModel.email = "same@umc.dev"
        try await viewModel.requestEmailVerification()
        try await viewModel.verifyEmailCode("111111")

        viewModel.handleEmailChanged()

        #expect(viewModel.isEmailVerified == true)
    }
}

@MainActor
@Suite("SignUpViewModel — 회원가입")
struct SignUpViewModelRegisterTests {

    @Test("폼이 유효하지 않으면 register()는 아무 것도 하지 않는다")
    func registerNoOpsWhenFormInvalid() async {
        let registerUseCase = MockRegisterUseCase()
        let viewModel = makeViewModel(registerUseCase: registerUseCase)

        await viewModel.register()

        #expect(registerUseCase.callCount == 0)
        #expect(viewModel.registerState == .idle)
    }

    @Test("가입 성공 + 세션 확립 → 재로그인 없이 registerState.loaded")
    func registerSuccessWithSessionEstablishedSkipsRelogin() async throws {
        let registerUseCase = MockRegisterUseCase()
        registerUseCase.result = .success(
            RegisterResult(memberId: "member-1", sessionEstablished: true)
        )
        let loginUseCase = MockLoginUseCase()
        let viewModel = try await makeValidFormViewModel(
            registerUseCase: registerUseCase,
            loginUseCase: loginUseCase
        )

        await viewModel.register()

        #expect(viewModel.registerState == .loaded("member-1"))
        #expect(viewModel.requiresManualLoginAfterRegister == false)
        #expect(loginUseCase.executeKakaoCallCount == 0)
        #expect(loginUseCase.executeAppleCallCount == 0)
        #expect(loginUseCase.executeGoogleCallCount == 0)
    }

    @Test("가입 성공 + 세션 미확립 + 카카오 재로그인 성공 → 수동 로그인 불필요")
    func registerSuccessWithoutSessionFallsBackToKakaoLogin() async throws {
        let registerUseCase = MockRegisterUseCase()
        registerUseCase.result = .success(
            RegisterResult(memberId: "member-2", sessionEstablished: false)
        )
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeKakaoResult = .success(.existingMember)
        let viewModel = try await makeValidFormViewModel(
            registerUseCase: registerUseCase,
            loginUseCase: loginUseCase,
            postRegisterLoginContext: .kakao(
                accessToken: "kakao-token",
                email: "member@umc.dev"
            )
        )

        await viewModel.register()

        #expect(viewModel.registerState == .loaded("member-2"))
        #expect(viewModel.requiresManualLoginAfterRegister == false)
        #expect(loginUseCase.executeKakaoCallCount == 1)
    }

    @Test("가입 성공 + 세션 미확립 + 재로그인 응답이 신규회원 → 수동 로그인 필요")
    func registerSuccessWithoutSessionAppleReloginFailureRequiresManualLogin() async throws {
        let registerUseCase = MockRegisterUseCase()
        registerUseCase.result = .success(
            RegisterResult(memberId: "member-3", sessionEstablished: false)
        )
        let loginUseCase = MockLoginUseCase()
        loginUseCase.executeAppleResult = .success(
            .newMember(verificationToken: "unexpected-token")
        )
        let viewModel = try await makeValidFormViewModel(
            registerUseCase: registerUseCase,
            loginUseCase: loginUseCase,
            postRegisterLoginContext: .apple(
                authorizationCode: "auth-code",
                email: nil,
                fullName: nil
            )
        )

        await viewModel.register()

        #expect(viewModel.registerState == .loaded("member-3"))
        #expect(viewModel.requiresManualLoginAfterRegister == true)
        #expect(loginUseCase.executeAppleCallCount == 1)
    }

    @Test("가입 성공 + 세션 미확립 + 재로그인 컨텍스트 없음 → 수동 로그인 필요")
    func registerSuccessWithoutSessionAndNoContextRequiresManualLogin() async throws {
        let registerUseCase = MockRegisterUseCase()
        registerUseCase.result = .success(
            RegisterResult(memberId: "member-4", sessionEstablished: false)
        )
        let loginUseCase = MockLoginUseCase()
        let viewModel = try await makeValidFormViewModel(
            registerUseCase: registerUseCase,
            loginUseCase: loginUseCase,
            postRegisterLoginContext: nil
        )

        await viewModel.register()

        #expect(viewModel.registerState == .loaded("member-4"))
        #expect(viewModel.requiresManualLoginAfterRegister == true)
        #expect(loginUseCase.executeKakaoCallCount == 0)
        #expect(loginUseCase.executeAppleCallCount == 0)
        #expect(loginUseCase.executeGoogleCallCount == 0)
    }

    @Test("가입 실패 → registerState.idle 복귀 + ErrorHandler Alert 노출")
    func registerFailureSetsIdleWithErrorAlert() async throws {
        let registerUseCase = MockRegisterUseCase()
        registerUseCase.result = .failure(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = try await makeValidFormViewModel(
            registerUseCase: registerUseCase,
            errorHandler: errorHandler
        )

        await viewModel.register()

        #expect(viewModel.registerState == .idle)
        #expect(errorHandler.currentError != nil)
    }
}

// MARK: - Helpers

private struct DummyError: Error {}

private let mockMandatoryTerms: [Terms] = [
    Terms(
        id: "terms-service",
        type: .service,
        link: "https://umc.dev/terms/service",
        isMandatory: true
    ),
    Terms(
        id: "terms-privacy",
        type: .privacy,
        link: "https://umc.dev/terms/privacy",
        isMandatory: true
    )
]

@MainActor
private func makeViewModel(
    fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol? = nil,
    sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol? = nil,
    verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol? = nil,
    resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol? = nil,
    registerUseCase: RegisterUseCaseProtocol? = nil,
    loginUseCase: LoginUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil,
    verificationToken: String = "oauth-verification-token",
    initialEmail: String? = nil,
    initialFullName: String? = nil,
    postRegisterLoginContext: PostRegisterLoginContext? = nil
) -> SignUpViewModel {
    let container = DIContainer()
    container.register(FetchSignUpDataUseCaseProtocol.self) {
        fetchSignUpDataUseCase ?? MockFetchSignUpDataUseCase()
    }
    container.register(SendEmailVerificationUseCaseProtocol.self) {
        sendEmailVerificationUseCase ?? MockSendEmailVerificationUseCase()
    }
    container.register(VerifyEmailCodeUseCaseProtocol.self) {
        verifyEmailCodeUseCase ?? MockVerifyEmailCodeUseCase()
    }
    container.register(ResendEmailVerificationUseCaseProtocol.self) {
        resendEmailVerificationUseCase ?? MockResendEmailVerificationUseCase()
    }
    container.register(RegisterUseCaseProtocol.self) {
        registerUseCase ?? MockRegisterUseCase()
    }
    container.register(LoginUseCaseProtocol.self) {
        loginUseCase ?? MockLoginUseCase()
    }

    return SignUpViewModel(
        container: container,
        errorHandler: errorHandler ?? ErrorHandler(),
        verificationToken: verificationToken,
        initialEmail: initialEmail,
        initialFullName: initialFullName,
        postRegisterLoginContext: postRegisterLoginContext
    )
}

/// 이름/닉네임/이메일/학교/이메일인증/필수약관을 모두 채운 유효한 폼 상태의 ViewModel을 만든다.
@MainActor
private func makeValidFormViewModel(
    registerUseCase: RegisterUseCaseProtocol? = nil,
    loginUseCase: LoginUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil,
    postRegisterLoginContext: PostRegisterLoginContext? = nil
) async throws -> SignUpViewModel {
    let fetchSignUpDataUseCase = MockFetchSignUpDataUseCase()
    fetchSignUpDataUseCase.fetchSchoolsResult = .success(
        [School(id: "1", name: "테스트대학교")]
    )
    fetchSignUpDataUseCase.fetchTermsResult = [
        .service: .success(mockMandatoryTerms[0]),
        .privacy: .success(mockMandatoryTerms[1])
    ]

    let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
    sendEmailVerificationUseCase.result = .success("email-verification-id")

    let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
    verifyEmailCodeUseCase.result = .success("email-verification-token")

    let viewModel = makeViewModel(
        fetchSignUpDataUseCase: fetchSignUpDataUseCase,
        sendEmailVerificationUseCase: sendEmailVerificationUseCase,
        verifyEmailCodeUseCase: verifyEmailCodeUseCase,
        registerUseCase: registerUseCase,
        loginUseCase: loginUseCase,
        errorHandler: errorHandler,
        postRegisterLoginContext: postRegisterLoginContext
    )

    await viewModel.fetchSchools()
    await viewModel.fetchTerms()

    viewModel.name = "홍길동"
    viewModel.nickname = "길동이"
    viewModel.email = "member@umc.dev"
    viewModel.selectedSchool = School(id: "1", name: "테스트대학교")

    try await viewModel.requestEmailVerification()
    try await viewModel.verifyEmailCode("123456")

    viewModel.termsAgreements["terms-service"] = true
    viewModel.termsAgreements["terms-privacy"] = true

    return viewModel
}

// MARK: - Mocks — UseCase

private final class MockFetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var fetchSchoolsResult: Result<[School], Error> = .failure(MockError.notStubbed)
    private(set) var fetchSchoolsCallCount = 0

    var fetchTermsResult: [TermsType: Result<Terms, Error>] = [:]
    private(set) var fetchTermsCallCount = 0
    private(set) var fetchTermsReceivedTypes: [TermsType] = []

    func fetchSchools() async throws -> [School] {
        fetchSchoolsCallCount += 1
        return try fetchSchoolsResult.get()
    }

    func fetchTerms(type: TermsType) async throws -> Terms {
        fetchTermsCallCount += 1
        fetchTermsReceivedTypes.append(type)
        guard let result = fetchTermsResult[type] else {
            throw MockError.notStubbed
        }
        return try result.get()
    }
}

private final class MockSendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<String, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedEmail: String?
    private(set) var receivedPurpose: EmailVerificationPurpose?

    func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String {
        callCount += 1
        receivedEmail = email
        receivedPurpose = purpose
        return try result.get()
    }
}

private final class MockVerifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<String, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedCode: String?

    func execute(emailVerificationId: String, verificationCode: String) async throws -> String {
        callCount += 1
        receivedCode = verificationCode
        return try result.get()
    }
}

private final class MockResendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Void, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0

    func execute(emailVerificationId: String) async throws {
        callCount += 1
        _ = try result.get()
    }
}

private final class MockRegisterUseCase: RegisterUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<RegisterResult, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedTermsAgreements: [TermsAgreement]?

    func execute(
        oAuthVerificationToken: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        profileImageId: String?,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterResult {
        callCount += 1
        receivedTermsAgreements = termsAgreements
        return try result.get()
    }
}

private final class MockLoginUseCase: LoginUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var executeKakaoResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var executeKakaoCallCount = 0

    var executeAppleResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var executeAppleCallCount = 0

    var executeGoogleResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var executeGoogleCallCount = 0

    func executeKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        executeKakaoCallCount += 1
        return try executeKakaoResult.get()
    }

    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        executeAppleCallCount += 1
        return try executeAppleResult.get()
    }

    func executeGoogle(accessToken: String) async throws -> OAuthLoginResult {
        executeGoogleCallCount += 1
        return try executeGoogleResult.get()
    }
}
