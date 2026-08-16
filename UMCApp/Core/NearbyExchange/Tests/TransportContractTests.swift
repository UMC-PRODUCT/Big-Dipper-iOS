//
//  TransportContractTests.swift
//  CoreNearbyExchangeTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import CoreNearbyExchange

@Suite("Transport 일반화 — 광고 파생·피어 표시 필드")
struct TransportContractTests {

    private func makeCard() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
            name: "제옹", nickname: "제옹", part: "IOS", generation: "12",
            university: "한양대학교", email: nil, github: nil, blog: nil,
            avatarURL: nil, cardLink: "umc://card/42"
        )
    }

    @Test("BLE 축약 광고는 cardID UUID 앞 8바이트와 version을 파생한다")
    func advertisementDerivation() throws {
        let advertisement = BLEAdvertisementPayload(card: try makeCard())

        #expect(advertisement.cardUUIDPrefix.count == 8)
        #expect(advertisement.version == 2)
    }

    @Test("cardID가 UUID 문자열이 아니면 UTF-8 앞 8바이트를 0 패딩해 쓴다")
    func advertisementDerivationFromNonUUID() throws {
        let card = try ExchangePayload(
            cardID: "abc", name: "제옹", nickname: "", part: "", generation: "",
            university: "", email: nil, github: nil, blog: nil, avatarURL: nil,
            cardLink: ""
        )

        let advertisement = BLEAdvertisementPayload(card: card)

        #expect(advertisement.cardUUIDPrefix.count == 8)
        #expect(advertisement.cardUUIDPrefix.prefix(3) == Data("abc".utf8))
    }

    @Test("DiscoveredPeer 표시 필드는 기본 nil — BLE 무 PII 정책과 공존한다")
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
