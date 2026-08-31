//
//  MockPeerCardRepository.swift
//  BusinessCardDomainTests
//
//  Created by euijjang97 on 8/28/26.
//

import Foundation
@testable import BusinessCardDomain

final class MockPeerCardRepository: PeerCardRepositoryProtocol, @unchecked Sendable {
    var fetchCardResult: Result<MyCard, Error> = .failure(MockError.notStubbed)
    private(set) var requestedMemberIds: [String] = []

    func fetchCard(memberId: String) async throws -> MyCard {
        requestedMemberIds.append(memberId)
        return try fetchCardResult.get()
    }
}
