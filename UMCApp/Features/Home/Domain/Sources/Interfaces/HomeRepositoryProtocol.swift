/// 홈 화면 프로필 관련 데이터 접근 계층 인터페이스.
public protocol HomeRepositoryProtocol {

    /// 홈 화면(시즌/세대 카드) 구성에 필요한 내 프로필을 조회한다.
    func fetchMyProfile() async throws -> HomeProfileResult
}
