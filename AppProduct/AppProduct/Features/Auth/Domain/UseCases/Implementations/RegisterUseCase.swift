//
//  RegisterUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

// MARK: - RegisterUseCase

/// 회원가입 UseCase 구현체
///
/// 서버가 가입 응답에 토큰을 함께 내려주면(`RegisterResult.tokenPair`) 즉시 저장하여
/// 별도 소셜 재로그인 없이 세션을 복구합니다. 이는 Apple의 1회용 `authorizationCode`를
/// 재사용하다 거절당하던 문제(#901)를 근본적으로 차단합니다. 토큰이 없으면 호출부가
/// 기존 소셜 재로그인 경로로 폴백합니다.
final class RegisterUseCase: RegisterUseCaseProtocol {

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

    func execute(request: RegisterRequestDTO) async throws -> RegisterResult {
        let result = try await repository.register(request: request)

        // 서버가 가입과 동시에 토큰을 발급한 경우 즉시 저장하고 재로그인을 생략합니다.
        if let tokenPair = result.tokenPair {
            try await tokenStore.save(
                accessToken: tokenPair.accessToken,
                refreshToken: tokenPair.refreshToken
            )
        }

        return result
    }
}
