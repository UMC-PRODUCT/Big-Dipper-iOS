//
//  RegisterUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 소셜 회원가입 UseCase 구현체
public final class RegisterUseCase: RegisterUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(
        oAuthVerificationToken: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        profileImageId: String?,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterResult {
        try await repository.register(
            oAuthVerificationToken: oAuthVerificationToken,
            name: name,
            nickname: nickname,
            emailVerificationToken: emailVerificationToken,
            schoolId: schoolId,
            profileImageId: profileImageId,
            termsAgreements: termsAgreements
        )
    }
}
