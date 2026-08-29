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

    @Test("DiscoveredPeer 표시 필드는 기본 nil — 광고가 싣지 않으면 익명이다")
    func peerDisplayFieldsDefaultNil() {
        let peer = DiscoveredPeer(id: "p1")

        #expect(peer.displayName == nil)
        #expect(peer.part == nil)
        #expect(peer.generation == nil)
    }

    /// 권한 거부는 권한 API 가 아니라 Bonjour 실패로 위장해 온다. 이 판정이 무너지면
    /// 화면은 원인 불문 「권한을 켜라」거나 원인 불문 「전송 오류」가 된다.
    @Test("Bonjour 정책 거부는 권한 거부로 분류한다")
    func policyDeniedIsPermissionDenied() {
        let error = NSError(
            domain: "NSNetServicesErrorDomain",
            code: -72000,
            userInfo: ["NSNetServicesErrorCode": -65570]
        )

        guard case .permissionDenied = NearbyError.startFailure(error) else {
            Issue.record("permissionDenied 로 분류되지 않음"); return
        }
    }

    @Test("그 밖의 Bonjour 실패는 원문을 들고 올라간다")
    func otherFailureKeepsUnderlying() {
        let error = NSError(
            domain: "NSNetServicesErrorDomain",
            code: -72000,
            userInfo: ["NSNetServicesErrorCode": -65539]
        )

        guard case .transportFailure = NearbyError.startFailure(error) else {
            Issue.record("transportFailure 로 분류되지 않음"); return
        }
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
