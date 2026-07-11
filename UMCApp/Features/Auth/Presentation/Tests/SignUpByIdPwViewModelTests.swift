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

    @Test("인증 완료 후 debounce를 거쳐 중복 확인이 1회 실행된다")
    func verificationCompleteChainsAvailabilityCheck() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )

        #expect(viewModel.emailAvailabilityState == .idle)

        try await waitForEmailAvailabilityDebounce(on: viewModel)

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

        try await waitForEmailAvailabilityDebounce(on: viewModel)

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

        // 연속 재검증(예: 코드 재입력) — 매 호출마다 이전 debounce 예약이 취소되고 새로 예약된다.
        // 아래 3개 호출은 debounce 간격(500ms)보다 훨씬 짧은 시간 안에 끝나므로, 마지막 예약만
        // 실제로 만료되어 실행된다.
        try await viewModel.verifyEmailCode("111111")
        try await viewModel.verifyEmailCode("222222")
        try await viewModel.verifyEmailCode("333333")

        try await waitForEmailAvailabilityDebounce(on: viewModel)

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

        try await waitForEmailAvailabilityDebounce(on: viewModel)

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
        try await waitForEmailAvailabilityDebounce(on: viewModel)
        #expect(viewModel.emailAvailabilityState == .loaded(true))

        viewModel.emailVerificationFlow.email = "changed@umc.dev"
        viewModel.emailVerificationFlow.handleEmailChanged()

        #expect(viewModel.emailAvailabilityState == .idle)
    }

    @Test("중복 확인 실패 후 retryEmailAvailabilityCheck()를 호출하면 debounce 없이 즉시 재확인한다")
    func retryEmailAvailabilityCheckRetriesImmediatelyAfterFailure() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .failure(DummyError())
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )
        try await waitForEmailAvailabilityDebounce(on: viewModel)
        guard case .failed = viewModel.emailAvailabilityState else {
            Issue.record("실패 상태를 기대했지만 \(viewModel.emailAvailabilityState)였다")
            return
        }

        checkEmailAvailabilityUseCase.result = .success(true)
        viewModel.retryEmailAvailabilityCheck()
        await viewModel.emailAvailabilityTask?.value

        #expect(checkEmailAvailabilityUseCase.callCount == 2)
        #expect(viewModel.emailAvailabilityState == .loaded(true))
    }

    @Test("중복 확인이 idle/loaded 상태면 retryEmailAvailabilityCheck()는 아무 것도 하지 않는다")
    func retryEmailAvailabilityCheckNoOpsWhenNotFailed() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let viewModel = try await makeVerifiedEmailViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )

        viewModel.retryEmailAvailabilityCheck()

        #expect(checkEmailAvailabilityUseCase.callCount == 0)
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

        viewModel.termsAgreementFlow.termsAgreements["terms-privacy"] = false

        #expect(viewModel.canSubmit == false)
    }

    @Test("약관이 아직 로딩되지 않았다면 나머지 필드가 모두 채워져도 canSubmit이 false다")
    func termsNotLoadedBlocksSubmit() async throws {
        let checkEmailAvailabilityUseCase = MockCheckEmailAvailabilityUseCase()
        checkEmailAvailabilityUseCase.result = .success(true)
        let viewModel = try await makeFormFilledButTermsNotLoadedViewModel(
            checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
        )

        #expect(viewModel.termsAgreementFlow.termsState == .idle)
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
        // debounce가 아직 만료되지 않았으므로 emailAvailabilityState는 .idle이다.

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
        try await waitForEmailAvailabilityDebounce(on: viewModel)

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

// MARK: - Helpers

private struct DummyError: Error {}

private enum Constants {
    /// 500ms debounce + CI 스케줄링 여유를 감안한 테스트 대기 시간.
    ///
    /// Item 6에서 debounce sleep을 결정적으로 대체하는 test double(actor 기반 수동 gate)을
    /// 시도했으나, `Task { ... }`으로 예약되는 debounce 작업이 MainActor에서 실행되는 반면
    /// gate의 `advance()`는 별도 액터에서 폴링하는 구조라 재개 시점이 서로 동기화되지 않아
    /// 테스트가 무한 대기(hang)하는 문제가 있었다. 안정적으로 재현 가능한 결정론적 대안을
    /// 짧은 시간 안에 확보하지 못해, 우선 실제 `Task.sleep` 기반 wall-clock 대기로 되돌린다
    /// (기존에 이미 검증된 안전한 패턴). 추후 별도 이슈에서 결정론적 test clock을 재시도한다.
    static let debounceWaitMilliseconds: Int = 800
}

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

/// 이메일 중복 확인 debounce(500ms)가 만료되어 확인이 실행될 때까지 대기한다.
private func waitForEmailAvailabilityDebounce(on viewModel: SignUpByIdPwViewModel) async throws {
    try await Task.sleep(for: .milliseconds(Constants.debounceWaitMilliseconds))
    await viewModel.emailAvailabilityTask?.value
}

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
        await viewModel.termsAgreementFlow.fetchTerms()
        viewModel.termsAgreementFlow.termsAgreements["terms-service"] = true
        viewModel.termsAgreementFlow.termsAgreements["terms-privacy"] = true
    }

    viewModel.emailVerificationFlow.email = email
    try await requestVerification(on: viewModel)

    return viewModel
}

/// Q3: 약관이 로딩되지 않은 상태에서 나머지 필드(이름/닉네임/비밀번호/이메일/학교/이메일인증)만
/// 채운 `SignUpByIdPwViewModel`을 만든다. `termsAgreementFlow.fetchTerms()`를 호출하지 않으므로
/// `termsState`는 `.idle`을 유지한다. 이메일 중복 확인 debounce도 내부적으로 완료시킨 뒤 반환한다.
@MainActor
private func makeFormFilledButTermsNotLoadedViewModel(
    checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol? = nil
) async throws -> SignUpByIdPwViewModel {
    let mocks = makeTermsNotLoadedSignUpMocks()
    let viewModel = makeViewModel(
        fetchSignUpDataUseCase: mocks.fetchSignUpDataUseCase,
        sendEmailVerificationUseCase: mocks.sendEmailVerificationUseCase,
        verifyEmailCodeUseCase: mocks.verifyEmailCodeUseCase,
        checkEmailAvailabilityUseCase: checkEmailAvailabilityUseCase
    )
    await viewModel.fetchSchools()
    viewModel.selectedSchool = School(id: "1", name: "테스트대학교")
    // termsAgreementFlow.fetchTerms()를 호출하지 않아 termsState == .idle을 유지한다.

    viewModel.name = "홍길동"
    viewModel.nickname = "길동이"
    viewModel.password = "password1234"
    viewModel.passwordConfirm = "password1234"
    viewModel.emailVerificationFlow.email = "member@umc.dev"
    try await requestVerification(on: viewModel)
    try await waitForEmailAvailabilityDebounce(on: viewModel)

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
    await viewModel.termsAgreementFlow.fetchTerms()

    viewModel.name = "홍길동"
    viewModel.nickname = "길동이"
    viewModel.password = "password1234"
    viewModel.passwordConfirm = "password1234"
    viewModel.emailVerificationFlow.email = "member@umc.dev"
    viewModel.selectedSchool = School(id: "1", name: "테스트대학교")

    try await requestVerification(on: viewModel)
    try await waitForEmailAvailabilityDebounce(on: viewModel)

    viewModel.termsAgreementFlow.termsAgreements["terms-service"] = true
    viewModel.termsAgreementFlow.termsAgreements["terms-privacy"] = true

    return viewModel
}

// MARK: - Mocks — UseCase

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
