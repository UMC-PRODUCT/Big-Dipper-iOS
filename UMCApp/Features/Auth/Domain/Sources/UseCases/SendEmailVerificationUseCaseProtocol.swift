/// 이메일 인증 발송 UseCase 인터페이스
public protocol SendEmailVerificationUseCaseProtocol {
    /// 이메일로 인증 코드를 발송한다.
    /// - Parameters:
    ///   - email: 인증할 이메일 주소
    ///   - purpose: 인증 목적 (회원가입/비밀번호 재설정)
    /// - Returns: 이메일 인증 요청 식별자(emailVerificationId)
    func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String
}
