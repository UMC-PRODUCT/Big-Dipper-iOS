//
//  CheckLoginIdAvailabilityUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

// MARK: - CheckLoginIdAvailabilityUseCase

/// 로그인 ID 중복 검사 UseCase 구현체
final class CheckLoginIdAvailabilityUseCase: CheckLoginIdAvailabilityUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(loginId: String) async throws -> Bool {
        try await repository.checkLoginIdAvailability(loginId: loginId)
    }
}
