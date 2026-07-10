import Testing
import Foundation
import CoreDI
import CoreDomain
import AuthDomain
import UMCFoundation
@testable import AuthPresentation

@MainActor
@Suite("SignUpByIdPwViewModel — 이메일 중복 확인 debounce")
struct SignUpByIdPwViewModelEmailAvailabilityTests {

    @Test("인증 완료 후 500ms debounce를 거쳐 중복 확인이 1회 실행된다")
    func verificationCompleteChainsAvailabilityCheck() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )

        #expect(viewModel.emailAvailabilityState == .idle)

        try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))

        #expect(checkEmailAvailabilityUseCase.callCount == 1)
        #expect(checkEmailAvailabilityUseCase.receivedEmail == "member@umc.dev")
        #expect(viewModel.emailAvailabilityState == .loaded(true))
    }

    @Test("중복된 이메일이면 사용 불가 결과가 그대로 반영된다")
    func duplicateEmailReflectsUnavailable() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(false)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )

        try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))

        #expect(viewModel.emailAvailabilityState == .loaded(false))
    }

    @Test("인증 재검증이 연속 호출되면 마지막 예약만 실제로 실행된다")
    func rapidReverificationOnlyFiresLastScheduledCheck() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-1")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token")
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase,
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )
        viewModel.emailVerificationFlow.email = "member@umc.dev"
        try await requestVerification(on: viewModel)

        // 연속 재검증(예: 코드 재입력) — 매 호출마다 이전 debounce 예약이 취소된다.
        try await viewModel.verifyEmailCode("111111")
        try await viewModel.verifyEmailCode("222222")
        try await viewModel.verifyEmailCode("333333")

        try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))

        #expect(checkEmailAvailabilityUseCase.callCount == 1)
        #expect(viewModel.emailAvailabilityState == .loaded(true))
    }

    @Test("이메일 변경으로 재검증하면 이전 예약은 취소되고 새 이메일만 확인된다")
    func emailChangeCancelsPendingCheckAndSchedulesNewOne() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
        sendEmailVerificationUseCase.result = .success("verify-id-2")
        let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
        verifyEmailCodeUseCase.result = .success("verify-token-2")
        let viewModel = makeViewModel(
            sendEmailVerificationUseCase: sendEmailVerificationUseCase,
            verifyEmailCodeUseCase: verifyEmailCodeUseCase,
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )
        viewModel.emailVerificationFlow.email = "first@umc.dev"
        try await requestVerification(on: viewModel)
        try await viewModel.verifyEmailCode("111111")

        viewModel.emailVerificationFlow.email = "second@umc.dev"
        viewModel.emailVerificationFlow.handleEmailChanged()
        try await requestVerification(on: viewModel)
        try await viewModel.verifyEmailCode("222222")

        try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))

        #expect(checkEmailAvailabilityUseCase.callCount == 1)
        #expect(checkEmailAvailabilityUseCase.receivedEmail == "second@umc.dev")
    }

    @Test("이메일 변경 시 이메일 중복 확인 상태가 초기화된다")
    func emailChangeResetsAvailabilityState() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )
        try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))
        #expect(viewModel.emailAvailabilityState == .loaded(true))

        viewModel.emailVerificationFlow.email = "changed@umc.dev"
        viewModel.emailVerificationFlow.handleEmailChanged()

        #expect(viewModel.emailAvailabilityState == .idle)
    }
}

@MainActor
@Suite("SignUpByIdPwViewModel — canSubmit")
struct SignUpByIdPwViewModelCanSubmitTests {

    @Test("모든 조건을 충족하면 canSubmit이 true다")
    func allConditionsSatisfiedMakesCanSubmitTrue() async throws {
        let viewModel = try await makeValidFormViewModel()
        #expect(viewModel.canSubmit == true)
    }

    @Test("비밀번호와 비밀번호 확인이 다르면 canSubmit이 false다")
    func passwordMismatchBlocksSubmit() async throws {
        let viewModel = try await makeValidFormViewModel()
        #expect(viewModel.canSubmit == true)

        viewModel.passwordConfirm = "different-password"

        #expect(viewModel.isPasswordConfirmed == false)
        #expect(viewModel.canSubmit == false)
    }

    @Test("필수 약관 중 하나라도 미동의면 canSubmit이 false다")
    func mandatoryTermDisagreementBlocksSubmit() async throws {
        let viewModel = try await makeValidFormViewModel()
        #expect(viewModel.canSubmit == true)

        viewModel.termsAgreements["terms-privacy"] = false

        #expect(viewModel.canSubmit == false)
    }

    @Test("약관이 아직 로딩되지 않았다면 나머지 필드가 모두 채워져도 canSubmit이 false다")
    func termsNotLoadedBlocksSubmit() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase,
            fillSchool: true
        )
        try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))
        viewModel.name = "홍길동"
        viewModel.nickname = "길동이"
        viewModel.password = "password1234"
        viewModel.passwordConfirm = "password1234"
        // fetchTerms()를 호출하지 않아 termsState == .idle을 유지한다.

        #expect(viewModel.termsState == .idle)
        #expect(viewModel.canSubmit == false)
    }

    @Test("이메일 중복 확인 전이면 canSubmit이 false다")
    func emailAvailabilityNotResolvedBlocksSubmit() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase,
            fillSchool: true,
            fillTerms: true
        )
        viewModel.name = "홍길동"
        viewModel.nickname = "길동이"
        viewModel.password = "password1234"
        viewModel.passwordConfirm = "password1234"
        // debounce 대기 없이 바로 확인 — emailAvailabilityState는 아직 .idle이다.

        #expect(viewModel.canSubmit == false)
    }

    @Test("이메일이 이미 사용 중이면 canSubmit이 false다")
    func duplicateEmailBlocksSubmit() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(false)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase,
            fillSchool: true,
            fillTerms: true
        )
        viewModel.name = "홍길동"
        viewModel.nickname = "길동이"
        viewModel.password = "password1234"
        viewModel.passwordConfirm = "password1234"
        try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))

        #expect(viewModel.emailAvailabilityState == .loaded(false))
        #expect(viewModel.canSubmit == false)
    }
}

@MainActor
@Suite("SignUpByIdPwViewModel — 회원가입")
struct SignUpByIdPwViewModelRegisterTests {

    @Test("canSubmit이 false면 register()는 아무 것도 하지 않는다")
    func registerNoOpsWhenCanSubmitFalse() async {
        let registerByEmailUseCase = MockRegisterByEmailUseCase()
        let viewModel = makeViewModel(registerByEmailUseCase: registerByEmailUseCase)

        await viewModel.register()

        #expect(registerByEmailUseCase.callCount == 0)
        #expect(viewModel.registerState == .idle)
    }

    @Test("가입 성공 + 프로필 승인됨 → registerState.loaded, isApprovedAfterRegister true")
    func registerSuccessWithApprovedProfile() async throws {
        let registerByEmailUseCase = MockRegisterByEmailUseCase()
        registerByEmailUseCase.result = .success(RegisterByIdPwResult(memberId: "member-1"))
        let fetchMemberProfileUseCase = MockFetchMemberProfileUseCase()
        fetchMemberProfileUseCase.result = .success(
            Profile(memberId: "member-1", name: "홍길동", nickname: "길동이", generations: ["10"])
        )
        let viewModel = try await makeValidFormViewModel(
            registerByEmailUseCase: registerByEmailUseCase,
            fetchMemberProfileUseCase: fetchMemberProfileUseCase
        )

        await viewModel.register()

        #expect(viewModel.registerState == .loaded("member-1"))
        #expect(viewModel.isApprovedAfterRegister == true)
        #expect(fetchMemberProfileUseCase.callCount == 1)

        let receivedAgreements = try #require(registerByEmailUseCase.receivedTermsAgreements)
        let sortedAgreements = receivedAgreements.sorted { $0.termsId < $1.termsId }
        #expect(sortedAgreements == [
            TermsAgreement(termsId: "terms-privacy", isAgreed: true),
            TermsAgreement(termsId: "terms-service", isAgreed: true)
        ])
    }

    @Test("가입 성공 + 프로필 미승인 → registerState.loaded, isApprovedAfterRegister false")
    func registerSuccessWithUnapprovedProfile() async throws {
        let registerByEmailUseCase = MockRegisterByEmailUseCase()
        registerByEmailUseCase.result = .success(RegisterByIdPwResult(memberId: "member-2"))
        let fetchMemberProfileUseCase = MockFetchMemberProfileUseCase()
        fetchMemberProfileUseCase.result = .success(
            Profile(memberId: "member-2", name: "홍길동", nickname: "길동이", generations: [])
        )
        let viewModel = try await makeValidFormViewModel(
            registerByEmailUseCase: registerByEmailUseCase,
            fetchMemberProfileUseCase: fetchMemberProfileUseCase
        )

        await viewModel.register()

        #expect(viewModel.registerState == .loaded("member-2"))
        #expect(viewModel.isApprovedAfterRegister == false)
    }

    @Test("가입 성공 + 프로필 재조회 실패 → 미승인으로 안전하게 폴백한다")
    func registerSuccessWithProfileFetchFailureFallsBackToUnapproved() async throws {
        let registerByEmailUseCase = MockRegisterByEmailUseCase()
        registerByEmailUseCase.result = .success(RegisterByIdPwResult(memberId: "member-3"))
        let fetchMemberProfileUseCase = MockFetchMemberProfileUseCase()
        fetchMemberProfileUseCase.result = .failure(DummyError())
        let viewModel = try await makeValidFormViewModel(
            registerByEmailUseCase: registerByEmailUseCase,
            fetchMemberProfileUseCase: fetchMemberProfileUseCase
        )

        await viewModel.register()

        #expect(viewModel.registerState == .loaded("member-3"))
        #expect(viewModel.isApprovedAfterRegister == false)
    }

    @Test("가입 실패 → registerState.idle 복귀 + ErrorHandler Alert 노출")
    func registerFailureSetsIdleWithErrorAlert() async throws {
        let registerByEmailUseCase = MockRegisterByEmailUseCase()
        registerByEmailUseCase.result = .failure(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = try await makeValidFormViewModel(
            registerByEmailUseCase: registerByEmailUseCase,
            errorHandler: errorHandler
        )

        await viewModel.register()

        #expect(viewModel.registerState == .idle)
        #expect(errorHandler.currentError != nil)
    }
}

// MARK: - Constants

private enum Constants {
    /// 500ms debounce + CI 스케줄링 여유를 감안한 테스트 대기 시간.
    static let debounceWaitMilliseconds: Int = 800
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
    checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol? = nil,
    registerByEmailUseCase: RegisterByEmailUseCaseProtocol? = nil,
    fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil
) -> SignUpByIdPwViewModel {
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
    container.register(CheckEmailAvailabilityUseCaseProtocol.self) {
        checkEmailAvailabilityUseCase ?? MockCheckEmailAvailabilityUseCase()
    }
    container.register(RegisterByEmailUseCaseProtocol.self) {
        registerByEmailUseCase ?? MockRegisterByEmailUseCase()
    }
    container.register(FetchMemberProfileUseCaseProtocol.self) {
        fetchMemberProfileUseCase ?? MockFetchMemberProfileUseCase()
    }

    return SignUpByIdPwViewModel(
        container: container,
        errorHandler: errorHandler ?? ErrorHandler()
    )
}

/// `requestEmailVerification()` → `verifyEmailCode()` 순서로 인증을 완료시킨다.
@MainActor
private func requestVerification(
    on viewModel: SignUpByIdPwViewModel,
    code: String = "123456"
) async throws {
    try await viewModel.emailVerificationFlow.requestEmailVerification()
    try await viewModel.verifyEmailCode(code)
}

/// 이메일 인증까지만 완료한(중복 확인은 debounce 대기 전) 상태의 ViewModel을 만든다.
@MainActor
private func makeVerifiedEmailViewModel(
    checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol? = nil,
    email: String = "member@umc.dev",
    fillSchool: Bool = false,
    fillTerms: Bool = false
) async throws -> SignUpByIdPwViewModel {
    let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
    sendEmailVerificationUseCase.result = .success("verify-id-1")
    let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
    verifyEmailCodeUseCase.result = .success("verify-token-1")

    var fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol?
    if fillSchool || fillTerms {
        let mock = MockFetchSignUpDataUseCase()
        mock.fetchSchoolsResult = .success([School(id: "1", name: "테스트대학교")])
        mock.fetchTermsResult = [
            .service: .success(mockMandatoryTerms[0]),
            .privacy: .success(mockMandatoryTerms[1])
        ]
        fetchSignUpDataUseCase = mock
    }

    let viewModel = makeViewModel(
        fetchSignUpDataUseCase: fetchSignUpDataUseCase,
        sendEmailVerificationUseCase: sendEmailVerificationUseCase,
        verifyEmailCodeUseCase: verifyEmailCodeUseCase,
        checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
    )

    if fillSchool {
        await viewModel.fetchSchools()
        viewModel.selectedSchool = School(id: "1", name: "테스트대학교")
    }
    if fillTerms {
        await viewModel.fetchTerms()
        viewModel.termsAgreements["terms-service"] = true
        viewModel.termsAgreements["terms-privacy"] = true
    }

    viewModel.emailVerificationFlow.email = email
    try await requestVerification(on: viewModel)

    return viewModel
}

/// 이름/닉네임/비밀번호/이메일/학교/이메일인증/이메일중복확인/필수약관을 모두 채운
/// 유효한 폼 상태의 ViewModel을 만든다.
@MainActor
private func makeValidFormViewModel(
    registerByEmailUseCase: RegisterByEmailUseCaseProtocol? = nil,
    fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol? = nil,
    errorHandler: ErrorHandler? = nil
) async throws -> SignUpByIdPwViewModel {
    let fetchSignUpDataUseCase = MockFetchSignUpDataUseCase()
    fetchSignUpDataUseCase.fetchSchoolsResult = .success([School(id: "1", name: "테스트대학교")])
    fetchSignUpDataUseCase.fetchTermsResult = [
        .service: .success(mockMandatoryTerms[0]),
        .privacy: .success(mockMandatoryTerms[1])
    ]

    let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
    sendEmailVerificationUseCase.result = .success("verify-id-1")

    let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
    verifyEmailCodeUseCase.result = .success("verify-token-1")

    let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
    checkEmailAvailabilityUseCase.result = .success(true)

    let viewModel = makeViewModel(
        fetchSignUpDataUseCase: fetchSignUpDataUseCase,
        sendEmailVerificationUseCase: sendEmailVerificationUseCase,
        verifyEmailCodeUseCase: verifyEmailCodeUseCase,
        checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase,
        registerByEmailUseCase: registerByEmailUseCase,
        fetchMemberProfileUseCase: fetchMemberProfileUseCase,
        errorHandler: errorHandler
    )

    await viewModel.fetchSchools()
    await viewModel.fetchTerms()

    viewModel.name = "홍길동"
    viewModel.nickname = "길동이"
    viewModel.password = "password1234"
    viewModel.passwordConfirm = "password1234"
    viewModel.emailVerificationFlow.email = "member@umc.dev"
    viewModel.selectedSchool = School(id: "1", name: "테스트대학교")

    try await requestVerification(on: viewModel)
    try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))

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

    func fetchSchools() async throws -> [School] {
        fetchSchoolsCallCount += 1
        return try fetchSchoolsResult.get()
    }

    func fetchTerms(type: TermsType) async throws -> Terms {
        fetchTermsCallCount += 1
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

    func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String {
        callCount += 1
        return try result.get()
    }
}

private final class MockVerifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<String, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0

    func execute(emailVerificationId: String, verificationCode: String) async throws -> String {
        callCount += 1
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

private final class MockCheckEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Bool, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedEmail: String?

    func execute(email: String) async throws -> Bool {
        callCount += 1
        receivedEmail = email
        return try result.get()
    }
}

private final class MockRegisterByEmailUseCase: RegisterByEmailUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<RegisterByIdPwResult, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedTermsAgreements: [TermsAgreement]?

    func execute(
        rawPassword: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterByIdPwResult {
        callCount += 1
        receivedTermsAgreements = termsAgreements
        return try result.get()
    }
}

private final class MockFetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol, @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Profile, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0

    func execute() async throws -> Profile {
        callCount += 1
        return try result.get()
    }
}
