/// 기존 챌린저 6자리 코드 등록 UseCase 구현체
public final class RegisterExistingChallengerUseCase: RegisterExistingChallengerUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(code: String) async throws {
        try await repository.registerExistingChallenger(code: code)
    }
}
