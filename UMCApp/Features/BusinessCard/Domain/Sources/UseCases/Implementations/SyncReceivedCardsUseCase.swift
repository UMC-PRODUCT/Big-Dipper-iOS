//
//  SyncReceivedCardsUseCase.swift
//  BusinessCardDomain
//
//  Created by JEONG on 8/30/26.
//

import Foundation

public final class SyncReceivedCardsUseCase:
    SyncReceivedCardsUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let repository: ReceivedCardRepositoryProtocol

    // MARK: - Init

    public init(repository: ReceivedCardRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws {
        try await repository.sync()
    }
}
