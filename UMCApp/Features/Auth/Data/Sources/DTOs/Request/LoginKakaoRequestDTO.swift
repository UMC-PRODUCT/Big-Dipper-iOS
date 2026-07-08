/// 카카오 소셜 로그인 요청 DTO
///
/// `POST /api/v1/auth/login/kakao`
public struct LoginKakaoRequestDTO: Encodable {
    /// 카카오 SDK 액세스 토큰
    public let accessToken: String
    /// 카카오 계정 이메일
    public let email: String

    public init(accessToken: String, email: String) {
        self.accessToken = accessToken
        self.email = email
    }
}
