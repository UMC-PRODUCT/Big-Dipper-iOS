import Foundation
@testable import AuthDomain

/// `AuthRegistrationRepositoryProtocol`의 테스트용 Mock 구현체
///
/// UseCase가 **어떤 메서드를 어떤 인자로 호출했는지**를 기록하고(`...CallCount`, `...Received...`),
/// 각 메서드가 반환/던질 값을 주입할 수 있습니다(`...Result` / `...Error`).
final class MockAuthRegistrationRepository:
    AuthRegistrationRepositoryProtocol, @unchecked Sendable {

    enum MockError: Error, Equatable {
        /// 테스트가 반환값을 주입하지 않은 메서드가 호출됨
        case notStubbed
    }

    // MARK: - sendEmailVerification

    var sendEmailVerificationResult: Result<String, Error> = .failure(MockError.notStubbed)
    private(set) var sendEmailVerificationCallCount = 0
    private(set) var sendEmailVerificationReceivedEmail: String?
    private(set) var sendEmailVerificationReceivedPurpose: EmailVerificationPurpose?

    func sendEmailVerification(
        email: String,
        purpose: EmailVerificationPurpose
    ) async throws -> String {
        sendEmailVerificationCallCount += 1
        sendEmailVerificationReceivedEmail = email
        sendEmailVerificationReceivedPurpose = purpose
        return try sendEmailVerificationResult.get()
    }

    // MARK: - resendEmailVerification

    var resendEmailVerificationError: Error?
    private(set) var resendEmailVerificationCallCount = 0
    private(set) var resendEmailVerificationReceivedEmailVerificationId: String?

    func resendEmailVerification(emailVerificationId: String) async throws {
        resendEmailVerificationCallCount += 1
        resendEmailVerificationReceivedEmailVerificationId = emailVerificationId
        if let resendEmailVerificationError {
            throw resendEmailVerificationError
        }
    }

    // MARK: - verifyEmailCode

    var verifyEmailCodeResult: Result<String, Error> = .failure(MockError.notStubbed)
    private(set) var verifyEmailCodeCallCount = 0
    private(set) var verifyEmailCodeReceivedEmailVerificationId: String?
    private(set) var verifyEmailCodeReceivedVerificationCode: String?

    func verifyEmailCode(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        verifyEmailCodeCallCount += 1
        verifyEmailCodeReceivedEmailVerificationId = emailVerificationId
        verifyEmailCodeReceivedVerificationCode = verificationCode
        return try verifyEmailCodeResult.get()
    }

    // MARK: - checkEmailAvailability

    var checkEmailAvailabilityResult: Result<Bool, Error> = .failure(MockError.notStubbed)
    private(set) var checkEmailAvailabilityCallCount = 0
    private(set) var checkEmailAvailabilityReceivedEmail: String?

    func checkEmailAvailability(email: String) async throws -> Bool {
        checkEmailAvailabilityCallCount += 1
        checkEmailAvailabilityReceivedEmail = email
        return try checkEmailAvailabilityResult.get()
    }

    // MARK: - fetchSchools

    var fetchSchoolsResult: Result<[School], Error> = .failure(MockError.notStubbed)
    private(set) var fetchSchoolsCallCount = 0

    func fetchSchools() async throws -> [School] {
        fetchSchoolsCallCount += 1
        return try fetchSchoolsResult.get()
    }

    // MARK: - fetchTerms

    var fetchTermsResult: Result<Terms, Error> = .failure(MockError.notStubbed)
    private(set) var fetchTermsCallCount = 0
    private(set) var fetchTermsReceivedType: TermsType?

    func fetchTerms(type: TermsType) async throws -> Terms {
        fetchTermsCallCount += 1
        fetchTermsReceivedType = type
        return try fetchTermsResult.get()
    }

    // MARK: - register

    var registerResult: Result<RegisterResult, Error> = .failure(MockError.notStubbed)
    private(set) var registerCallCount = 0
    private(set) var registerReceivedOAuthVerificationToken: String?
    private(set) var registerReceivedName: String?
    private(set) var registerReceivedNickname: String?
    private(set) var registerReceivedEmailVerificationToken: String?
    private(set) var registerReceivedSchoolId: String?
    private(set) var registerReceivedProfileImageId: String?
    private(set) var registerReceivedTermsAgreements: [TermsAgreement]?

    func register(
        oAuthVerificationToken: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        profileImageId: String?,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterResult {
        registerCallCount += 1
        registerReceivedOAuthVerificationToken = oAuthVerificationToken
        registerReceivedName = name
        registerReceivedNickname = nickname
        registerReceivedEmailVerificationToken = emailVerificationToken
        registerReceivedSchoolId = schoolId
        registerReceivedProfileImageId = profileImageId
        registerReceivedTermsAgreements = termsAgreements
        return try registerResult.get()
    }

    // MARK: - registerByEmail

    var registerByEmailResult: Result<RegisterByIdPwResult, Error> = .failure(MockError.notStubbed)
    private(set) var registerByEmailCallCount = 0
    private(set) var registerByEmailReceivedRawPassword: String?
    private(set) var registerByEmailReceivedName: String?
    private(set) var registerByEmailReceivedNickname: String?
    private(set) var registerByEmailReceivedEmailVerificationToken: String?
    private(set) var registerByEmailReceivedSchoolId: String?
    private(set) var registerByEmailReceivedTermsAgreements: [TermsAgreement]?

    func registerByEmail(
        rawPassword: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterByIdPwResult {
        registerByEmailCallCount += 1
        registerByEmailReceivedRawPassword = rawPassword
        registerByEmailReceivedName = name
        registerByEmailReceivedNickname = nickname
        registerByEmailReceivedEmailVerificationToken = emailVerificationToken
        registerByEmailReceivedSchoolId = schoolId
        registerByEmailReceivedTermsAgreements = termsAgreements
        return try registerByEmailResult.get()
    }

    // MARK: - registerCredential

    var registerCredentialError: Error?
    private(set) var registerCredentialCallCount = 0
    private(set) var registerCredentialReceivedRawPassword: String?

    func registerCredential(rawPassword: String) async throws {
        registerCredentialCallCount += 1
        registerCredentialReceivedRawPassword = rawPassword
        if let registerCredentialError {
            throw registerCredentialError
        }
    }

    // MARK: - registerExistingChallenger

    var registerExistingChallengerError: Error?
    private(set) var registerExistingChallengerCallCount = 0
    private(set) var registerExistingChallengerReceivedCode: String?

    func registerExistingChallenger(code: String) async throws {
        registerExistingChallengerCallCount += 1
        registerExistingChallengerReceivedCode = code
        if let registerExistingChallengerError {
            throw registerExistingChallengerError
        }
    }
}
