//
//  ChangePasswordUseCase.swift
//  AppProduct
//

import Foundation

final class ChangePasswordUseCase: ChangePasswordUseCaseProtocol {

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func execute(
        currentPassword: String,
        newPassword: String
    ) async throws {
        try await repository.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword
        )
    }
}
