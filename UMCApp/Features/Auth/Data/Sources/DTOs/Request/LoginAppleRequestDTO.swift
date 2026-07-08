/// Apple 소셜 로그인 요청 DTO
///
/// `POST /api/v1/auth/login/apple`
///
/// `email` / `fullName`은 최초 로그인 시에만 Apple이 내려주므로
/// 빈 문자열 또는 nil인 경우 페이로드에서 키를 제거한다.
public struct LoginAppleRequestDTO: Encodable {
    /// Apple Sign In 인증 코드
    public let authorizationCode: String
    /// Apple 계정 이메일 (최초 로그인 시)
    public let email: String?
    /// Apple 계정 이름 (최초 로그인 시)
    public let fullName: String?
    /// 클라이언트 플랫폼 (`ANDROID` / `IOS` / `WEB`)
    ///
    /// Apple은 플랫폼별로 다른 `client_id`(iOS Bundle ID vs Web Services ID)를
    /// 사용하기 때문에 서버가 토큰 교환 시 식별이 필요하다.
    public let clientType: String

    public init(
        authorizationCode: String,
        email: String?,
        fullName: String?,
        clientType: String = "IOS"
    ) {
        self.authorizationCode = authorizationCode
        self.email = (email?.isEmpty == false) ? email : nil
        self.fullName = (fullName?.isEmpty == false) ? fullName : nil
        self.clientType = clientType
    }

    private enum CodingKeys: String, CodingKey {
        case authorizationCode
        case email
        case fullName
        case clientType
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authorizationCode, forKey: .authorizationCode)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(fullName, forKey: .fullName)
        try container.encode(clientType, forKey: .clientType)
    }
}
