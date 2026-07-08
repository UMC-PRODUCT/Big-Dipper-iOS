/// 내 프로필 조회 UseCase 인터페이스
public protocol FetchMyProfileUseCaseProtocol {
    /// - Returns: 내 프로필 정보
    func execute() async throws -> Profile
}
