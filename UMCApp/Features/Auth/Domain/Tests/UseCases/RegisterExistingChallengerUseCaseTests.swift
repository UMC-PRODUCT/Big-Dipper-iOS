//
//  RegisterExistingChallengerUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
@testable import AuthDomain

@Suite("RegisterExistingChallengerUseCase — Repository 위임 검증")
struct RegisterExistingChallengerUseCaseTests {

    @Test("execute() 호출 시 repository.registerExistingChallenger()에 파라미터를 그대로 전달한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        let useCase = RegisterExistingChallengerUseCase(repository: repository)

        try await useCase.execute(code: "AB12CD")

        #expect(repository.registerExistingChallengerCallCount == 1)
        #expect(repository.registerExistingChallengerReceivedCode == "AB12CD")
    }

    @Test("repository.registerExistingChallenger()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.registerExistingChallengerError = AuthTestError.boom
        let useCase = RegisterExistingChallengerUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            try await useCase.execute(code: "AB12CD")
        }
    }
}
