import Testing
@testable import AuthDomain

@Suite("ResetPasswordUseCase — Repository 위임 검증")
struct ResetPasswordUseCaseTests {

    @Test("execute() 호출 시 repository.resetPassword()에 파라미터를 그대로 전달한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        let useCase = ResetPasswordUseCase(repository: repository)

        try await useCase.execute(
            emailVerificationToken: "email-verification-token",
            newPassword: "newPassword123"
        )

        #expect(repository.resetPasswordCallCount == 1)
        #expect(repository.resetPasswordReceivedEmailVerificationToken == "email-verification-token")
        #expect(repository.resetPasswordReceivedNewPassword == "newPassword123")
    }

    @Test("repository.resetPassword()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.resetPasswordError = AuthTestError.boom
        let useCase = ResetPasswordUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            try await useCase.execute(
                emailVerificationToken: "email-verification-token",
                newPassword: "newPassword123"
            )
        }
    }
}
