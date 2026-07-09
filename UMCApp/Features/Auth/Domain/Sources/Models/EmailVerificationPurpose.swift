/// 이메일 인증 목적.
///
/// rawValue는 서버 요청 바디 필드에 그대로 사용된다.
public enum EmailVerificationPurpose: String, Equatable, Sendable {
    case register = "REGISTER"
    case passwordReset = "PASSWORD_RESET"
}
