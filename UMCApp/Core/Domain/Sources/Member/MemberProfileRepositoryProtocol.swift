/// 정본 프로필 조회 데이터 접근 계층 인터페이스.
public protocol MemberProfileRepositoryProtocol: Sendable {

    /// 내 프로필을 조회한다.
    func fetchMyProfile() async throws -> Profile
}
