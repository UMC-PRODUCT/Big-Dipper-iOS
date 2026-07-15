//
//  CheckEmailAvailabilityUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일 중복 확인 UseCase 구현체
public final class CheckEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(email: String) async throws -> Bool {
        try await repository.checkEmailAvailability(email: email)
    }
}
