//
//  MockAuthUseCases.swift
//  AuthPresentationTests
//
//  Created by euijjang97 on 7/11/26.
//

import Foundation
import AuthDomain

// MARK: - Mocks — UseCase
//
// `SignUpViewModelTests`/`SignUpByIdPwViewModelTests`/`EmailVerificationFlowTests`/
// `ResetPasswordViewModelTests`가 각자 동일하게 선언하던 Mock UseCase 4종을 공용화했다 (#956).

/// `FetchSignUpDataUseCaseProtocol`의 테스트용 Mock 구현체.
final class MockFetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol, @unchecked Sendable {
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

/// `SendEmailVerificationUseCaseProtocol`의 테스트용 Mock 구현체.
final class MockSendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
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

/// `VerifyEmailCodeUseCaseProtocol`의 테스트용 Mock 구현체.
final class MockVerifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol, @unchecked Sendable {
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

/// `ResendEmailVerificationUseCaseProtocol`의 테스트용 Mock 구현체.
final class MockResendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol,
    @unchecked Sendable {
    enum MockError: Error, Equatable { case notStubbed }

    var result: Result<Void, Error> = .failure(MockError.notStubbed)
    private(set) var callCount = 0
    private(set) var receivedEmailVerificationId: String?

    func execute(emailVerificationId: String) async throws {
        callCount += 1
        receivedEmailVerificationId = emailVerificationId
        _ = try result.get()
    }
}

// MARK: - Q3 공용 셋업 ("약관 미로딩 시 제출 차단")

/// 학교 조회·이메일 인증은 성공하도록 스텁하되 약관(Terms)은 의도적으로 스텁하지 않은
/// Mock 3종 세트를 만든다.
///
/// `SignUpViewModelTests`와 `SignUpByIdPwViewModelTests`가 "약관이 아직 로딩되지 않은 상태에서
/// 나머지 필드가 모두 채워져도 제출이 차단되는지" 검증하는 테스트(Q3)에서 동일한 스텁 조합을
/// 각자 구성하던 것을 통합했다 (#956). 호출자가 반환된 Mock으로 `fetchSchools()`/이메일 인증만
/// 진행하고 `fetchTerms()`를 호출하지 않으면 `termsState == .idle` 시나리오가 재현된다.
func makeTermsNotLoadedSignUpMocks(
    schoolId: String = "1",
    schoolName: String = "테스트대학교",
    emailVerificationId: String = "verify-id",
    emailVerificationToken: String = "verify-token"
) -> (
    fetchSignUpDataUseCase: MockFetchSignUpDataUseCase,
    sendEmailVerificationUseCase: MockSendEmailVerificationUseCase,
    verifyEmailCodeUseCase: MockVerifyEmailCodeUseCase
) {
    let fetchSignUpDataUseCase = MockFetchSignUpDataUseCase()
    fetchSignUpDataUseCase.fetchSchoolsResult = .success([School(id: schoolId, name: schoolName)])

    let sendEmailVerificationUseCase = MockSendEmailVerificationUseCase()
    sendEmailVerificationUseCase.result = .success(emailVerificationId)

    let verifyEmailCodeUseCase = MockVerifyEmailCodeUseCase()
    verifyEmailCodeUseCase.result = .success(emailVerificationToken)

    return (fetchSignUpDataUseCase, sendEmailVerificationUseCase, verifyEmailCodeUseCase)
}
