//
//  MockReceivedCardRepository.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
@testable import BusinessCardDomain

final class MockReceivedCardRepository: ReceivedCardRepositoryProtocol, @unchecked Sendable {

    // MARK: - Stub

    var fetchAllResult: Result<[ReceivedCard], Error> = .success([])
    var searchResult: Result<[ReceivedCard], Error> = .success([])
    var saveError: Error?
    var deleteError: Error?
    var deleteAllError: Error?
    var countResult: Result<Int, Error> = .success(0)

    // MARK: - Capture

    private(set) var fetchAllCallCount = 0
    private(set) var lastSearchQuery: String?
    private(set) var savedCards: [ReceivedCard] = []
    private(set) var deletedIds: [String] = []
    private(set) var deleteAllCallCount = 0

    // MARK: - ReceivedCardRepositoryProtocol

    func fetchAll() async throws -> [ReceivedCard] {
        fetchAllCallCount += 1
        return try fetchAllResult.get()
    }

    func search(query: String) async throws -> [ReceivedCard] {
        lastSearchQuery = query
        return try searchResult.get()
    }

    func save(_ card: ReceivedCard) async throws {
        if let saveError { throw saveError }
        savedCards.append(card)
    }

    func delete(id: String) async throws {
        if let deleteError { throw deleteError }
        deletedIds.append(id)
    }

    func deleteAll() async throws {
        if let deleteAllError { throw deleteAllError }
        deleteAllCallCount += 1
        deletedIds.append(contentsOf: savedCards.map(\.id))
    }

    func count() async throws -> Int {
        try countResult.get()
    }
}
