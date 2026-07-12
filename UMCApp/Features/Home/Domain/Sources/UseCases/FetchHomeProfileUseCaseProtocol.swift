/// 홈 화면 내 프로필 조회 UseCase 인터페이스
public protocol FetchHomeProfileUseCaseProtocol {

    /// 홈 화면(시즌/세대 카드) 구성에 필요한 내 프로필을 조회한다.
    /// - Parameter forceRefresh: `true`이면 세션 프로필 캐시를 우회해 서버에서 새로 조회한다.
    /// - Returns: 시즌/세대 카드 구성에 필요한 내 프로필 정보
    func execute(forceRefresh: Bool) async throws -> HomeProfileResult
}

extension FetchHomeProfileUseCaseProtocol {

    /// 내 프로필을 조회한다 (캐시 허용 기본 경로, `forceRefresh: false`와 동일).
    public func execute() async throws -> HomeProfileResult {
        try await execute(forceRefresh: false)
    }
}
