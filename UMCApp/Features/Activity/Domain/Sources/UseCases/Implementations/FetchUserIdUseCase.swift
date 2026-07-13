//
//  FetchUserIdUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation

/// `FetchUserIdUseCaseProtocol` 의 기본 구현체
///
/// 현재 사용자 식별자 조회를 `CurrentUserIdProviding` 에 위임하는 얇은 facade 입니다.
public final class FetchUserIdUseCase: FetchUserIdUseCaseProtocol {

    // MARK: - Property

    private let provider: CurrentUserIdProviding

    // MARK: - Init

    public init(provider: CurrentUserIdProviding) {
        self.provider = provider
    }

    // MARK: - Function

    public func execute() async throws -> UserID {
        try await provider.fetchCurrentUserId()
    }
}
