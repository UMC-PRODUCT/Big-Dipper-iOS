//
//  LoginByEmailUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

// MARK: - LoginByEmailUseCase

/// 이메일 로그인 UseCase 구현체
///
/// 로그인 성공 시 토큰을 즉시 저장합니다 (소셜 로그인 `LoginUseCase`와 동일 패턴).
final class LoginByEmailUseCase: LoginByEmailUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol
    private let tokenStore: TokenStore

    // MARK: - Init

    init(
        repository: AuthRepositoryProtocol,
        tokenStore: TokenStore
    ) {
        self.repository = repository
        self.tokenStore = tokenStore
    }

    // MARK: - Function

    func execute(
        email: String,
        password: String
    ) async throws -> LoginByIdPwResult {
        let result = try await repository.loginByEmail(
            EmailLoginRequestDTO(
                email: email,
                password: password
            )
        )
        try await tokenStore.save(
            accessToken: result.tokenPair.accessToken,
            refreshToken: result.tokenPair.refreshToken
        )
        return result
    }
}
