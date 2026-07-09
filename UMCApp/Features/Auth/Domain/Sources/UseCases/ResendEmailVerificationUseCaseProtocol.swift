/// 이메일 인증 코드 재전송 UseCase 인터페이스
public protocol ResendEmailVerificationUseCaseProtocol {
    /// 이메일 인증 코드를 재전송한다.
    /// - Parameter emailVerificationId: 발송 시 발급받은 이메일 인증 요청 식별자
    func execute(emailVerificationId: String) async throws
}
