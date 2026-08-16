//
//  FetchPeerCardUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

public final class FetchPeerCardUseCase: FetchPeerCardUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let repository: PeerCardRepositoryProtocol

    // MARK: - Init

    public init(repository: PeerCardRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(memberId: String) async throws -> MyCard {
        try await repository.fetchCard(memberId: memberId)
    }
}
