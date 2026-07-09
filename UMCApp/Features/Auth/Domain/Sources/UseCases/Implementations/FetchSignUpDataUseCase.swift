/// 회원가입 화면에 필요한 학교/약관 데이터 조회 UseCase 구현체
public final class FetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func fetchSchools() async throws -> [School] {
        try await repository.fetchSchools()
    }

    public func fetchTerms(type: TermsType) async throws -> Terms {
        try await repository.fetchTerms(type: type)
    }
}
