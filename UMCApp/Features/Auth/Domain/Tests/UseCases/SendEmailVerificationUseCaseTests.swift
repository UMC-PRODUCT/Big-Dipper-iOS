import Testing
@testable import AuthDomain

@Suite("SendEmailVerificationUseCase — Repository 위임 검증")
struct SendEmailVerificationUseCaseTests {

    @Test("execute() 호출 시 repository.sendEmailVerification()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        repository.sendEmailVerificationResult = .success("51")
        let useCase = SendEmailVerificationUseCase(repository: repository)

        let result = try await useCase.execute(email: "test@umc.dev", purpose: .register)

        #expect(result == "51")
        #expect(repository.sendEmailVerificationCallCount == 1)
        #expect(repository.sendEmailVerificationReceivedEmail == "test@umc.dev")
        #expect(repository.sendEmailVerificationReceivedPurpose == .register)
    }

    @Test("repository.sendEmailVerification()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.sendEmailVerificationResult = .failure(AuthTestError.boom)
        let useCase = SendEmailVerificationUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute(email: "test@umc.dev", purpose: .register)
        }
    }
}
