//
//  LoginByEmailUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 7/31/26.
//

import Testing
@testable import AuthDomain

@Suite("LoginByEmailUseCase — Repository 위임 검증")
struct LoginByEmailUseCaseTests {

    @Test("execute() 호출 시 repository.loginByEmail()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        repository.loginByEmailResult = .success(LoginByIdPwResult(memberId: "100"))
        let useCase = LoginByEmailUseCase(repository: repository)

        let result = try await useCase.execute(email: "test@umc.dev", password: "P@ssw0rd!")

        #expect(result == LoginByIdPwResult(memberId: "100"))
        #expect(repository.loginByEmailCallCount == 1)
        #expect(repository.loginByEmailReceivedEmail == "test@umc.dev")
        #expect(repository.loginByEmailReceivedPassword == "P@ssw0rd!")
    }

    @Test("repository.loginByEmail()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRepository()
        repository.loginByEmailResult = .failure(AuthTestError.boom)
        let useCase = LoginByEmailUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute(email: "test@umc.dev", password: "P@ssw0rd!")
        }
    }
}
