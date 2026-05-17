//
//  RegisterCredentialUseCase.swift
//  AppProduct
//

import Foundation

// MARK: - RegisterCredentialUseCase

final class RegisterCredentialUseCase: RegisterCredentialUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(rawPassword: String) async throws {
        try await repository.registerCredential(rawPassword: rawPassword)
    }
}
