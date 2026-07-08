/// 앱 부트스트랩 시점의 인증 상태 판정 UseCase 인터페이스
public protocol CheckAuthStatusUseCaseProtocol {
    /// 토큰 존재 → 세션 강제 갱신 → 프로필 조회 → 승인 판정 순으로 인증 상태를 확인한다.
    /// - Returns: 판정된 부트스트랩 인증 상태
    func execute() async -> AuthBootstrapStatus
}
