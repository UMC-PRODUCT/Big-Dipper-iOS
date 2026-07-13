//
//  ResendEmailVerificationUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일 인증 코드 재전송 UseCase 구현체
public final class ResendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(emailVerificationId: String) async throws {
        try await repository.resendEmailVerification(emailVerificationId: emailVerificationId)
    }
}
