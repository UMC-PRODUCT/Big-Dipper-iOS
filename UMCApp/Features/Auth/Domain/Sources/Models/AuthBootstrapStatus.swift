/// 부트스트랩 시점의 인증 상태 판정 결과.
public enum AuthBootstrapStatus: Equatable, Sendable {
    /// 유효 세션 + 승인된 챌린저 — 메인으로 진입 가능
    case approved
    /// 유효 세션이지만 아직 기수 배정 전(승인 대기) — 후속 이슈(#945)에서 전용 상태로 연결 예정
    case pendingApproval
    /// 세션 없음 또는 세션 검증 실패 — 로그인 필요
    case notLoggedIn
}
