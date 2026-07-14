//
//  ResetPasswordUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/10/26.
//

/// 비밀번호 재설정 UseCase 구현체
public final class ResetPasswordUseCase: ResetPasswordUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(emailVerificationToken: String, newPassword: String) async throws {
        try await repository.resetPassword(
            emailVerificationToken: emailVerificationToken,
            newPassword: newPassword
        )
    }
}
