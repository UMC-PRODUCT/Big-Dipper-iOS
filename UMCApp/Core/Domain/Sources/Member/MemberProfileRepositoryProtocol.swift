/// 정본 프로필 조회 데이터 접근 계층 인터페이스.
///
/// 구현체는 세션 단위 캐싱 여부를 자유롭게 선택할 수 있다. `fetchMyProfile()`은 기존 소비부
/// (Auth/Home/MyPage)의 계약을 그대로 유지하고, 캐싱을 지원하는 구현체(`CachedMemberProfileRepository`)만
/// `forceRefresh`/`primeCache`/`invalidateCache`를 의미 있게 구현한다. 캐싱을 지원하지 않는 구현체는
/// 기본 구현(그대로 위임하거나 no-op)을 그대로 사용하면 된다.
public protocol MemberProfileRepositoryProtocol: Sendable {

    /// 내 프로필을 조회한다.
    /// - Note: 캐싱 구현체 기준으로는 `fetchMyProfile(forceRefresh: false)`와 동일하다.
    func fetchMyProfile() async throws -> Profile

    /// 내 프로필을 조회한다.
    /// - Parameter forceRefresh: `true`이면 캐시를 무시하고 서버에서 새로 조회한다.
    func fetchMyProfile(forceRefresh: Bool) async throws -> Profile

    /// 서버가 반환한 최신 프로필 스냅샷으로 캐시를 갱신한다.
    ///
    /// 프로필 수정 API(링크 수정, 이미지 변경 등)는 응답으로 최신 스냅샷을 함께 반환하므로,
    /// 별도 재조회 없이 이 스냅샷으로 캐시를 최신화할 때 사용한다. 캐싱을 지원하지 않는
    /// 구현체는 no-op이다.
    func primeCache(with profile: Profile) async

    /// 캐시를 무효화한다 (로그아웃/세션 만료 등). 캐싱을 지원하지 않는 구현체는 no-op이다.
    func invalidateCache() async
}

extension MemberProfileRepositoryProtocol {

    public func fetchMyProfile(forceRefresh: Bool) async throws -> Profile {
        try await fetchMyProfile()
    }

    public func primeCache(with profile: Profile) async {}

    public func invalidateCache() async {}
}
