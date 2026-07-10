/// 비밀번호 재설정 요청 DTO
///
/// `PATCH /api/v1/auth/password/reset`
public struct ResetPasswordRequestDTO: Encodable {
    /// 이메일 인증 완료 토큰(`PASSWORD_RESET` 목적)
    public let emailVerificationToken: String
    /// 새로 설정할 평문 비밀번호
    public let newPassword: String

    public init(emailVerificationToken: String, newPassword: String) {
        self.emailVerificationToken = emailVerificationToken
        self.newPassword = newPassword
    }
}
