/// 내 프로필 조회 UseCase 구현체
public final class FetchMyProfileUseCase: FetchMyProfileUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> Profile {
        try await repository.fetchMyProfile()
    }
}
