/// OAuth 회원 비밀번호 추가 등록 요청 DTO
///
/// `POST /api/v1/auth/credentials`
public struct RegisterCredentialRequestDTO: Encodable {
    /// 평문 비밀번호
    public let rawPassword: String

    public init(rawPassword: String) {
        self.rawPassword = rawPassword
    }
}
