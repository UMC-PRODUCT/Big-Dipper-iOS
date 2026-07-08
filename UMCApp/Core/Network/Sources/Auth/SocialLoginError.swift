import Foundation

/// 소셜 로그인 SDK 전반에서 공통으로 정규화하는 에러입니다.
///
/// 카카오/Apple/Google 각 SDK는 사용자가 로그인 시트를 취소했을 때 서로 다른 타입의 에러를
/// 던집니다. 각 LoginManager가 이 케이스로 정규화해 상위 레이어(ViewModel)가 SDK별 타입을
/// 몰라도 "취소" 여부만으로 분기할 수 있게 합니다.
public enum SocialLoginError: Error, Equatable, Sendable {
    /// 사용자가 로그인 시트를 취소함 (에러 알럿을 띄우지 않아야 함)
    case cancelled
}
