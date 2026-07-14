//
//  VerifyEmailCodeUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일 인증 코드 검증 UseCase 구현체
public final class VerifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        try await repository.verifyEmailCode(
            emailVerificationId: emailVerificationId,
            verificationCode: verificationCode
        )
    }
}
