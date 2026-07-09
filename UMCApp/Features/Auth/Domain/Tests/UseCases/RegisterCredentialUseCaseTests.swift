import Testing
@testable import AuthDomain

@Suite("RegisterCredentialUseCase — Repository 위임 검증")
struct RegisterCredentialUseCaseTests {

    @Test("execute() 호출 시 repository.registerCredential()에 파라미터를 그대로 전달한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        let useCase = RegisterCredentialUseCase(repository: repository)

        try await useCase.execute(rawPassword: "P@ssw0rd!")

        #expect(repository.registerCredentialCallCount == 1)
        #expect(repository.registerCredentialReceivedRawPassword == "P@ssw0rd!")
    }

    @Test("repository.registerCredential()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.registerCredentialError = AuthTestError.boom
        let useCase = RegisterCredentialUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            try await useCase.execute(rawPassword: "P@ssw0rd!")
        }
    }
}
