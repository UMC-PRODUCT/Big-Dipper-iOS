import Testing
@testable import AuthDomain

@Suite("CheckEmailAvailabilityUseCase — Repository 위임 검증")
struct CheckEmailAvailabilityUseCaseTests {

    @Test("execute() 호출 시 repository.checkEmailAvailability()에 파라미터를 그대로 전달하고 결과를 반환한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockAuthRegistrationRepository()
        repository.checkEmailAvailabilityResult = .success(true)
        let useCase = CheckEmailAvailabilityUseCase(repository: repository)

        let result = try await useCase.execute(email: "test@umc.dev")

        #expect(result == true)
        #expect(repository.checkEmailAvailabilityCallCount == 1)
        #expect(repository.checkEmailAvailabilityReceivedEmail == "test@umc.dev")
    }

    @Test("execute()는 이미 사용 중인 이메일이면 false를 그대로 전달한다")
    func executePropagatesUnavailableResult() async throws {
        let repository = MockAuthRegistrationRepository()
        repository.checkEmailAvailabilityResult = .success(false)
        let useCase = CheckEmailAvailabilityUseCase(repository: repository)

        let result = try await useCase.execute(email: "taken@umc.dev")

        #expect(result == false)
    }

    @Test("repository.checkEmailAvailability()가 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockAuthRegistrationRepository()
        repository.checkEmailAvailabilityResult = .failure(AuthTestError.boom)
        let useCase = CheckEmailAvailabilityUseCase(repository: repository)

        await #expect(throws: AuthTestError.boom) {
            _ = try await useCase.execute(email: "test@umc.dev")
        }
    }
}
