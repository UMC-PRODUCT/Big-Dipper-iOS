//
//  RegisterUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

// MARK: - RegisterUseCase

/// 회원가입 UseCase 구현체
final class RegisterUseCase: RegisterUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(request: RegisterRequestDTO) async throws -> String {
        try await repository.register(request: request)
    }
}
