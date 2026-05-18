//
//  SendEmailVerificationUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

// MARK: - SendEmailVerificationUseCase

/// 이메일 인증 발송 UseCase 구현체
final class SendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(
        email: String,
        purpose: EmailVerificationPurpose
    ) async throws -> String {
        try await repository.sendEmailVerification(
            email: email,
            purpose: purpose
        )
    }
}
