import Testing
@testable import HomeDomain

@Suite("RegisterFCMTokenUseCase — repository 위임 검증")
struct RegisterFCMTokenUseCaseTests {

    @Test("토큰을 repository에 그대로 위임한다")
    func delegatesTokenToRepository() async throws {
        let repository = MockHomeRepository()
        let useCase = RegisterFCMTokenUseCase(repository: repository)

        try await useCase.execute(fcmToken: "fcm-token-abc")

        #expect(repository.registerFCMTokenCallCount == 1)
        #expect(repository.registerFCMTokenReceivedToken == "fcm-token-abc")
    }

    @Test("repository가 던진 에러를 그대로 전파한다")
    func propagatesRepositoryError() async {
        let repository = MockHomeRepository()
        repository.registerFCMTokenResult = .failure(HomeTestError.boom)
        let useCase = RegisterFCMTokenUseCase(repository: repository)

        await #expect(throws: HomeTestError.boom) {
            try await useCase.execute(fcmToken: "fcm-token-abc")
        }
    }
}
