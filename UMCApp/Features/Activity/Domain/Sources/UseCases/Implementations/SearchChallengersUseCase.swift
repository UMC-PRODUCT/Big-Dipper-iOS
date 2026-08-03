//
//  SearchChallengersUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation

/// `SearchChallengersUseCaseProtocol` 의 기본 구현체
///
/// 조회를 `MemberRepositoryProtocol` 에 위임하는 얇은 facade 입니다.
public final class SearchChallengersUseCase: SearchChallengersUseCaseProtocol {

    // MARK: - Property

    private let repository: MemberRepositoryProtocol

    // MARK: - Init

    public init(repository: MemberRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(
        keyword: String?,
        cursor: Int?,
        size: Int
    ) async throws -> ChallengerSearchPage {
        try await repository.searchChallengers(
            keyword: keyword,
            cursor: cursor,
            size: size
        )
    }
}
