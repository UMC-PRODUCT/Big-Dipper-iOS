//
//  ResetPasswordUseCase.swift
//  AppProduct
//

import Foundation

final class ResetPasswordUseCase: ResetPasswordUseCaseProtocol {

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func execute(
        emailVerificationToken: String,
        newPassword: String
    ) async throws {
        try await repository.resetPassword(
            emailVerificationToken: emailVerificationToken,
            newPassword: newPassword
        )
    }
}
