//
//  CheckEmailAvailabilityUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

// MARK: - CheckEmailAvailabilityUseCase

/// 이메일 중복 검사 UseCase 구현체
final class CheckEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(email: String) async throws -> Bool {
        try await repository.checkEmailAvailability(email: email)
    }
}
