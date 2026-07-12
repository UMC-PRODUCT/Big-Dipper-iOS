/// 홈 화면 내 프로필 조회 UseCase 구현체
public final class FetchHomeProfileUseCase: FetchHomeProfileUseCaseProtocol {

    // MARK: - Property

    private let repository: HomeRepositoryProtocol

    // MARK: - Init

    public init(repository: HomeRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(forceRefresh: Bool) async throws -> HomeProfileResult {
        try await repository.fetchMyProfile(forceRefresh: forceRefresh)
    }
}
