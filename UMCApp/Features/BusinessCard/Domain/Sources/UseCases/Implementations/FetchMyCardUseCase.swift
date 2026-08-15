//
//  FetchMyCardUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

public final class FetchMyCardUseCase: FetchMyCardUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let repository: BusinessCardRepositoryProtocol

    // MARK: - Init

    public init(repository: BusinessCardRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(forceRefresh: Bool) async throws -> MyCard {
        try await repository.fetchMyCard(forceRefresh: forceRefresh)
    }
}
