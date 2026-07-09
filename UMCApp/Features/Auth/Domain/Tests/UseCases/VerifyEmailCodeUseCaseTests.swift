import Testing
@testable import AuthDomain

@Suite("VerifyEmailCodeUseCase — Repository 위임 검증")
struct VerifyEmailCodeUseCaseTests {

    @Test("execute() 호출 시 repository.verifyEmailCode()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        repository.verifyEmailCodeResult = .success("email-verification-token")
        let useCase = VerifyEmailCodeUseCase(repository: repository)

        let result = try await useCase.execute(
            emailVerificationId: "51",
            verificationCode: "123456"
        )

        #expect(result == "email-verification-token")
        #expect(repository.verifyEmailCodeCallCount == 1)
        #expect(repository.verifyEmailCodeReceivedEmailVerificationId == "51")
        #expect(repository.verifyEmailCodeReceivedVerificationCode == "123456")
    }

    @Test("repository.verifyEmailCode()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.verifyEmailCodeResult = .failure(AuthTestError.boom)
        let useCase = VerifyEmailCodeUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute(emailVerificationId: "51", verificationCode: "123456")
        }
    }
}
