//
//  ResendEmailVerificationUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
@testable import AuthDomain

@Suite("ResendEmailVerificationUseCase — Repository 위임 검증")
struct ResendEmailVerificationUseCaseTests {

    @Test("execute() 호출 시 repository.resendEmailVerification()에 파라미터를 그대로 전달한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        let useCase = ResendEmailVerificationUseCase(repository: repository)

        try await useCase.execute(emailVerificationId: "51")

        #expect(repository.resendEmailVerificationCallCount == 1)
        #expect(repository.resendEmailVerificationReceivedEmailVerificationId == "51")
    }

    @Test("repository.resendEmailVerification()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.resendEmailVerificationError = AuthTestError.boom
        let useCase = ResendEmailVerificationUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            try await useCase.execute(emailVerificationId: "51")
        }
    }
}
