//
//  DeleteReceivedCardUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

public final class DeleteReceivedCardUseCase:
    DeleteReceivedCardUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let repository: ReceivedCardRepositoryProtocol

    // MARK: - Init

    public init(repository: ReceivedCardRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(id: String) async throws {
        try await repository.delete(id: id)
    }

    public func executeAll() async throws {
        try await repository.deleteAll()
    }
}
