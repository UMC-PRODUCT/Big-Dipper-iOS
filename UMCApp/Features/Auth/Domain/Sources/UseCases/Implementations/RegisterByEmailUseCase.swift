/// 이메일(ID/PW) 회원가입 UseCase 구현체
public final class RegisterByEmailUseCase: RegisterByEmailUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(
        rawPassword: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterByIdPwResult {
        try await repository.registerByEmail(
            rawPassword: rawPassword,
            name: name,
            nickname: nickname,
            emailVerificationToken: emailVerificationToken,
            schoolId: schoolId,
            termsAgreements: termsAgreements
        )
    }
}
