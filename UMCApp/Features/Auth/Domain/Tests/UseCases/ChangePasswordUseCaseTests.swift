//
//  ChangePasswordUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 8/10/26.
//

import Testing
@testable import AuthDomain

@Suite("ChangePasswordUseCase — Repository 위임 검증")
struct ChangePasswordUseCaseTests {

    @Test("execute() 호출 시 repository.changePassword()에 파라미터를 그대로 전달한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRepository()
        let useCase = ChangePasswordUseCase(repository: repository)

        try await useCase.execute(
            currentPassword: "currentPassword123",
            newPassword: "newPassword123"
        )

        #expect(repository.changePasswordCallCount == 1)
        #expect(repository.changePasswordReceivedCurrentPassword == "currentPassword123")
        #expect(repository.changePasswordReceivedNewPassword == "newPassword123")
    }

    @Test("현재 비밀번호가 틀려 repository가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRepository()
        repository.changePasswordError = AuthTestError.boom
        let useCase = ChangePasswordUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            try await useCase.execute(
                currentPassword: "wrongPassword",
                newPassword: "newPassword123"
            )
        }
    }
}
