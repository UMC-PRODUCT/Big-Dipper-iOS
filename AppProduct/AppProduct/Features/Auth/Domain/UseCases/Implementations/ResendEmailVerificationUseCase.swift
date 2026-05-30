//
//  ResendEmailVerificationUseCase.swift
//  AppProduct
//

import Foundation

final class ResendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol {

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func execute(emailVerificationId: String) async throws {
        try await repository.resendEmailVerification(
            emailVerificationId: emailVerificationId
        )
    }
}
