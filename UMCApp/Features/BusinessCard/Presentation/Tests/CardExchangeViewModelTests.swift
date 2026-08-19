//
//  CardExchangeViewModelTests.swift
//  BusinessCardPresentationTests
//
//  Created by One on 8/18/26.
//

import Foundation
import Testing
import UMCFoundation
import BusinessCardDomain
import CoreNearbyExchange
@testable import BusinessCardPresentation

@MainActor
@Suite("CardExchangeViewModel — 교환 세션 피어 목록·전송·완료")
struct CardExchangeViewModelTests {

    // MARK: - Session

    @Test("세션을 시작하면 발견된 피어가 목록에 쌓인다")
    func peersAccumulate() async {
        let exchange = StubExchangeCards(events: [
            .scanning,
            .peerFound(makePeer(id: "a")),
            .peerFound(makePeer(id: "b")),
        ])
        let sut = makeSUT(exchange: exchange)

        await sut.start()

        #expect(sut.peers.map(\.id) == ["a", "b"])
    }

    /// `foundPeer` 는 같은 피어를 여러 번 흘릴 수 있다. 그대로 쌓으면 같은 사람이
    /// 목록에 두 줄로 뜬다.
    @Test("같은 피어가 다시 발견돼도 한 줄로 유지된다")
    func duplicatePeerIsReplaced() async {
        let exchange = StubExchangeCards(events: [
            .peerFound(makePeer(id: "a", name: "옛 이름")),
            .peerFound(makePeer(id: "a", name: "새 이름")),
        ])
        let sut = makeSUT(exchange: exchange)

        await sut.start()

        #expect(sut.peers.count == 1)
        #expect(sut.peers.first?.displayName == "새 이름")
    }

    /// 거리는 교환과 무관하게 계속 흐른다. 새 피어를 만들지 않고 그 행의 값만 갱신해야 한다.
    @Test("거리 갱신은 새 행을 만들지 않고 그 행의 값만 바꾼다")
    func distanceUpdatesInPlace() async {
        let exchange = StubExchangeCards(events: [
            .peerFound(makePeer(id: "a")),
            .distanceUpdated(peerID: "a", meters: 2.1),
        ])
        let sut = makeSUT(exchange: exchange)

        await sut.start()

        #expect(sut.peers.count == 1)
        #expect(sut.peers.first?.distanceMeters == 2.1)
    }

    @Test("모르는 피어의 거리 갱신은 무시한다")
    func distanceForUnknownPeerIgnored() async {
        let exchange = StubExchangeCards(events: [.distanceUpdated(peerID: "ghost", meters: 1.0)])
        let sut = makeSUT(exchange: exchange)

        await sut.start()

        #expect(sut.peers.isEmpty)
    }

    // MARK: - Receive

    @Test("명함을 받으면 완료 상태가 되고 상대 이름을 들고 있다")
    func receivedCardCompletesSession() async {
        let exchange = StubExchangeCards(events: [.received(makeReceivedCard(name: "박의정"))])
        let sut = makeSUT(exchange: exchange)

        await sut.start()

        #expect(sut.completedCard?.profile.name == "박의정")
    }

    /// 「계속 교환하기」로 다시 시작할 때 이전 완료 화면이 남아 있으면 즉시 다시 뜬다.
    @Test("다시 시작하면 이전 완료 결과를 비운다")
    func restartClearsCompletion() async {
        let sut = makeSUT(exchange: StubExchangeCards(events: [
            .received(makeReceivedCard(name: "박의정")),
        ]))
        await sut.start()
        #expect(sut.completedCard != nil)

        await sut.start()
        sut.dismissCompletion()

        #expect(sut.completedCard == nil)
    }

    // MARK: - Send

    @Test("피어를 고르면 그 피어에게 내 명함을 보낸다")
    func sendForwardsPeer() async {
        let exchange = StubExchangeCards(events: [.peerFound(makePeer(id: "a"))])
        let sut = makeSUT(exchange: exchange)
        await sut.start()

        await sut.send(to: makePeer(id: "a"))

        #expect(exchange.sentPeerIDs == ["a"])
    }

    @Test("전송이 실패하면 에러를 알린다")
    func sendFailureIsReported() async {
        let errorHandler = ErrorHandler()
        let exchange = StubExchangeCards(events: [], sendError: StubError.boom)
        let sut = makeSUT(exchange: exchange, errorHandler: errorHandler)
        await sut.start()

        await sut.send(to: makePeer(id: "a"))

        #expect(errorHandler.currentError != nil)
    }

    // MARK: - Failure

    @Test("명함을 못 불러오면 세션을 시작하지 않는다")
    func cardFailureSkipsSession() async {
        let exchange = StubExchangeCards(events: [.peerFound(makePeer(id: "a"))])
        let sut = makeSUT(fetch: StubFetchMyCard(error: StubError.boom), exchange: exchange)

        await sut.start()

        #expect(sut.myCard.error != nil)
        #expect(exchange.startCount == .zero)
    }

    @Test("세션이 실패 이벤트를 흘리면 화면에 남긴다")
    func sessionFailureIsSurfaced() async {
        let sut = makeSUT(exchange: StubExchangeCards(events: [.failed(.transportFailure(underlying: NearbyError.invalidPayload("연결 시간 초과")))]))

        await sut.start()

        #expect(sut.sessionFailed)
    }

    // MARK: - Teardown

    @Test("화면을 떠나면 세션을 멈춘다")
    func stopEndsSession() async {
        let exchange = StubExchangeCards(events: [])
        let sut = makeSUT(exchange: exchange)
        await sut.start()

        await sut.stop()

        #expect(exchange.stopCount == 1)
    }
}

// MARK: - Fixture

private enum StubError: Error {
    case boom
}

private func makeMyCard() -> MyCard {
    MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
    )
}

private func makePeer(id: String, name: String = "이름") -> DiscoveredPeer {
    DiscoveredPeer(
        id: id,
        cardUUIDPrefix: Data(),
        version: 1,
        flags: 0,
        displayName: name,
        part: "IOS",
        generation: "10",
        avatarURL: nil
    )
}

private func makeReceivedCard(name: String) -> ReceivedCard {
    ReceivedCard(
        id: "card-1",
        profile: MyCard(
            memberId: "7", name: name, nickname: "닉",
            part: .design, generation: "11", university: "중앙대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
        ),
        exchangedAt: Date(timeIntervalSince1970: .zero),
        exchangeContext: nil
    )
}

@MainActor
private func makeSUT(
    fetch: StubFetchMyCard = StubFetchMyCard(card: makeMyCard()),
    exchange: StubExchangeCards = StubExchangeCards(events: []),
    errorHandler: ErrorHandler = ErrorHandler()
) -> CardExchangeViewModel {
    CardExchangeViewModel(
        fetchMyCard: fetch,
        exchangeCards: exchange,
        errorHandler: errorHandler
    )
}

// MARK: - Stub

private final class StubFetchMyCard: FetchMyCardUseCaseProtocol, @unchecked Sendable {

    private let card: MyCard?
    private let error: Error?

    init(card: MyCard? = nil, error: Error? = nil) {
        self.card = card
        self.error = error
    }

    func execute(forceRefresh: Bool) async throws -> MyCard {
        if let error { throw error }
        return card ?? makeMyCard()
    }
}

/// 이벤트를 전부 흘린 뒤 스트림을 닫는다 — `start()` 의 소비 루프가 끝나야 테스트가 진행된다.
private final class StubExchangeCards: ExchangeCardsUseCaseProtocol, @unchecked Sendable {

    private let events: [ExchangeEvent]
    private let sendError: Error?
    private(set) var sentPeerIDs: [String] = []
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(events: [ExchangeEvent], sendError: Error? = nil) {
        self.events = events
        self.sendError = sendError
    }

    func start(myCard: MyCard) -> AsyncStream<ExchangeEvent> {
        startCount += 1
        return AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func send(myCard: MyCard, to peer: DiscoveredPeer) async throws {
        sentPeerIDs.append(peer.id)
        if let sendError { throw sendError }
    }

    func stop() async {
        stopCount += 1
    }
}
