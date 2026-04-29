//
//  LoginByIdPwUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

// MARK: - LoginByIdPwUseCase

/// ID/PW 로그인 UseCase 구현체
///
/// 로그인 성공 시 토큰을 즉시 저장합니다 (소셜 로그인 `LoginUseCase`와 동일 패턴).
final class LoginByIdPwUseCase: LoginByIdPwUseCaseProtocol {

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
        loginId: String,
        password: String
    ) async throws -> LoginByIdPwResult {
        let result = try await repository.loginByIdPw(
            LoginByIdPwRequestDTO(
                loginId: loginId,
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
