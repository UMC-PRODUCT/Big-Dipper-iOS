/// 인증/세션 관련 데이터 접근 계층 인터페이스.
///
/// `NetworkClient`/`TokenStore` 같은 Core 인프라 타입을 Domain 레이어에 노출하지 않도록
/// 세션 존재 확인, 강제 갱신, 프로필 조회를 최소 계약으로 추상화한다.
public protocol AuthRepositoryProtocol {

    /// 저장된 액세스 토큰 존재 여부를 확인한다. (토큰 유효성 자체는 보장하지 않음)
    func hasSession() async -> Bool

    /// 리프레시 토큰으로 세션을 강제 갱신한다.
    func refreshSession() async throws

    /// 내 프로필을 조회한다.
    func fetchMyProfile() async throws -> Profile
}
