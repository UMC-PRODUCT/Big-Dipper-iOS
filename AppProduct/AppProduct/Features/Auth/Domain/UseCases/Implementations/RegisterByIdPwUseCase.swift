//
//  RegisterByIdPwUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

// MARK: - RegisterByIdPwUseCase

/// ID/PW 회원가입 UseCase 구현체
///
/// 가입과 동시에 토큰이 발급되므로 별도 로그인 호출 없이 즉시 저장하여 메인 진입을 지원합니다.
final class RegisterByIdPwUseCase: RegisterByIdPwUseCaseProtocol {

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
        request: RegisterByIdPwRequestDTO
    ) async throws -> RegisterByIdPwResult {
        let result = try await repository.registerByIdPw(request)
        try await tokenStore.save(
            accessToken: result.tokenPair.accessToken,
            refreshToken: result.tokenPair.refreshToken
        )
        return result
    }
}
