//
//  ExchangeCardsUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import UMCFoundation
import CoreNearbyExchange
@testable import BusinessCardDomain

@Suite("ExchangeCardsUseCase — 광고·스캔·수신 저장·타임아웃 오케스트레이션")
struct ExchangeCardsUseCaseTests {

    private let myCard = MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
    )

    private func makePeer() -> DiscoveredPeer {
        DiscoveredPeer(id: "peer-1", cardUUIDPrefix: Data(), version: 2, flags: 0,
                       displayName: "상대")
    }

    private func makePeerPayload() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "CARD-PEER", name: "상대", nickname: "상대닉", part: "DESIGN",
            generation: "11", university: "중앙대학교", email: nil, github: nil,
            linkedIn: nil, blog: nil, avatarURL: nil, cardLink: "umc://card/7"
        )
    }

    @Test("시작하면 광고·스캔 이벤트와 발견 피어·수신 명함이 모두 흐른다")
    func fullSession() async throws {
        let transport = MockNearbyTransport(
            stubbedPeers: [makePeer()],
            stubbedPayloads: [try makePeerPayload()]
        )
        let received = MockReceivedCardRepository()
        let save = SaveReceivedCardUseCase(repository: received)
        // 짧은 타임아웃으로 세션을 스스로 끝낸다 — `.received` 즉시 stop하면 아직
        // 방출되지 않은 이벤트가 잘려 간헐 실패한다(Mock receive()는 즉시 yield).
        let sut = ExchangeCardsUseCase(
            transport: transport,
            saveReceivedCard: save,
            sessionTimeout: .milliseconds(200)
        )

        var events: [ExchangeEvent] = []
        for await event in sut.start(myCard: myCard) {
            events.append(event)
        }

        #expect(events.contains(.advertising))
        #expect(events.contains(.scanning))
        #expect(events.contains { if case .peerFound = $0 { return true }; return false })
        guard case .received(let card)? = events.last(where: {
            if case .received = $0 { return true }; return false
        }) else {
            Issue.record("received 이벤트 없음"); return
        }
        #expect(card.id == "CARD-PEER")
        #expect(received.savedCards.count == 1)
        #expect(transport.advertisedCards.count == 1)
    }

    /// transport 가 소실을 알아도 UseCase 가 흘리지 않으면 화면은 유령 행을 못 지운다.
    @Test("transport 소실 신호는 peerLost 이벤트로 흐른다")
    func lostPeerIsForwarded() async {
        let transport = MockNearbyTransport(
            stubbedPeers: [makePeer()],
            stubbedDiscoveryEvents: [.lost(peerID: "peer-1")]
        )
        let sut = ExchangeCardsUseCase(
            transport: transport,
            saveReceivedCard: SaveReceivedCardUseCase(repository: MockReceivedCardRepository()),
            sessionTimeout: .milliseconds(200)
        )

        var events: [ExchangeEvent] = []
        for await event in sut.start(myCard: myCard) {
            events.append(event)
        }

        #expect(events.contains(.peerLost(peerID: "peer-1")))
    }

    @Test("send는 transport에 내 명함 페이로드를 전달한다")
    func sendDelegates() async throws {
        let transport = MockNearbyTransport()
        let sut = ExchangeCardsUseCase(
            transport: transport,
            saveReceivedCard: SaveReceivedCardUseCase(repository: MockReceivedCardRepository())
        )

        try await sut.send(myCard: myCard, to: makePeer())

        #expect(transport.sentPayloads.count == 1)
        #expect(transport.sentPayloads.first?.name == "정의찬")
        #expect(transport.sentPayloads.first?.cardLink == CardLink(memberId: "42").urlString)
    }

    @Test("타임아웃이 지나면 sessionExpired failed 이벤트 후 스트림이 끝난다")
    func timeoutEndsSession() async {
        let sut = ExchangeCardsUseCase(
            transport: MockNearbyTransport(),
            saveReceivedCard: SaveReceivedCardUseCase(repository: MockReceivedCardRepository()),
            sessionTimeout: .milliseconds(50)
        )

        var sawExpired = false
        for await event in sut.start(myCard: myCard) {
            if case .failed(.sessionExpired) = event { sawExpired = true }
        }

        #expect(sawExpired)
    }

    @Test("stop하면 광고가 중지되고 스트림이 끝난다")
    func stopCancelsSession() async {
        let transport = MockNearbyTransport()
        let sut = ExchangeCardsUseCase(
            transport: transport,
            saveReceivedCard: SaveReceivedCardUseCase(repository: MockReceivedCardRepository())
        )

        let stream = sut.start(myCard: myCard)
        await sut.stop()
        for await _ in stream {} // finish 확인 (무한 대기면 테스트 타임아웃)

        #expect(transport.didStopAdvertising)
    }

    @Test("start를 다시 부르면 이전 세션 스트림이 먼저 종료된다")
    func restartFinishesPreviousStream() async {
        let sut = ExchangeCardsUseCase(
            transport: MockNearbyTransport(),
            saveReceivedCard: SaveReceivedCardUseCase(repository: MockReceivedCardRepository()),
            sessionTimeout: .milliseconds(50)
        )

        let first = sut.start(myCard: myCard)
        _ = sut.start(myCard: myCard)
        for await _ in first {} // 이전 스트림이 안 닫히면 영구 대기 → 테스트 타임아웃

        await sut.stop()
    }
}
