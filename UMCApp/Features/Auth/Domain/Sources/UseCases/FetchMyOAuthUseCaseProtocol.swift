/// 내 OAuth 연동 정보 조회 UseCase 인터페이스
public protocol FetchMyOAuthUseCaseProtocol {
    /// 내 OAuth 연동 정보를 조회한다.
    /// - Returns: 연동된 OAuth 목록
    func execute() async throws -> [MemberOAuth]
}
