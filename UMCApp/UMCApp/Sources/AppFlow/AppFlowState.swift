/// 앱 전체 화면 상태.
///
/// 앱 진입~홈 진입 수직 슬라이스의 최소 상태만 담는다.
/// `signUp` / `pendingApproval` 등은 각 상태를 도입하는 후속 이슈에서 케이스가 추가된다.
enum AppFlowState: Equatable {
    /// 부트스트랩 화면 (토큰/프로필 확인 후 로그인·메인 여부 판단)
    case bootstrap
    /// 로그인 화면
    case login
    /// 메인 화면 (탭 셸)
    case main
}
