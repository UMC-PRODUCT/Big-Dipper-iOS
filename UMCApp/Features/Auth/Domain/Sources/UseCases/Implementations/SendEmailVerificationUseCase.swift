/// 이메일 인증 발송 UseCase 구현체
public final class SendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String {
        try await repository.sendEmailVerification(email: email, purpose: purpose)
    }
}
