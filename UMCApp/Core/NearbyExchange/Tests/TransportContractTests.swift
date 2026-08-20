//
//  TransportContractTests.swift
//  CoreNearbyExchangeTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import CoreNearbyExchange

@Suite("Transport 계약 — 피어 표시 필드·Mock 광고")
struct TransportContractTests {

    private func makeCard() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
            name: "제옹", nickname: "제옹", part: "IOS", generation: "12",
            university: "한양대학교", email: nil, github: nil, linkedIn: nil, blog: nil,
            avatarURL: nil, cardLink: "umc://card/42"
        )
    }

    @Test("DiscoveredPeer 표시 필드는 기본 nil — 핸드셰이크 전에는 익명이다")
    func peerDisplayFieldsDefaultNil() {
        let peer = DiscoveredPeer(id: "p1", cardUUIDPrefix: Data(), version: 1, flags: 0)

        #expect(peer.displayName == nil)
        #expect(peer.part == nil)
        #expect(peer.generation == nil)
    }

    @Test("Mock은 광고한 명함을 기록한다")
    func mockRecordsAdvertisedCard() async throws {
        let mock = MockNearbyTransport()

        try await mock.startAdvertising(card: try makeCard())

        #expect(mock.advertisedCards.count == 1)
        #expect(mock.advertisedCards.first?.name == "제옹")
        #expect(mock.didStartAdvertising)
    }
}
