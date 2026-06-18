//
//  LoginUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

// MARK: - LoginUseCase

/// 소셜 로그인 UseCase 구현체
///
/// 로그인 API 호출 후 기존 회원이면 토큰을 저장합니다.
final class LoginUseCase: LoginUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol
    private let tokenStore: TokenStore

    // MARK: - Init

    init(repository: AuthRepositoryProtocol, tokenStore: TokenStore) {
        self.repository = repository
        self.tokenStore = tokenStore
    }

    // MARK: - Function

    func executeKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult {
        let result = try await repository.loginKakao(
            accessToken: accessToken,
            email: email
        )
        try await saveTokenIfNeeded(result)
        return result
    }

    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        let result = try await repository.loginApple(
            authorizationCode: authorizationCode,
            email: email,
            fullName: fullName
        )
        try await saveTokenIfNeeded(result)
        return result
    }

    func executeGoogle(
        accessToken: String
    ) async throws -> OAuthLoginResult {
        let result = try await repository.loginGoogle(accessToken: accessToken)
        try await saveTokenIfNeeded(result)
        return result
    }
}

// MARK: - Private

private extension LoginUseCase {
    /// 기존 회원이면 토큰 저장
    func saveTokenIfNeeded(_ result: OAuthLoginResult) async throws {
        if case .existingMember(let tokenPair) = result {
            try await tokenStore.save(
                accessToken: tokenPair.accessToken,
                refreshToken: tokenPair.refreshToken
            )
        }
    }
}
