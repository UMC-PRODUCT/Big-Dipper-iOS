//
//  CardLinkReceiveViewModelTests.swift
//  BusinessCardPresentationTests
//
//  Created by One on 8/19/26.
//

import Foundation
import Testing
import UMCFoundation
import BusinessCardDomain
import CoreNearbyExchange
@testable import BusinessCardPresentation

@MainActor
@Suite("CardLinkReceiveViewModel — QR 링크로 받은 명함 저장")
struct CardLinkReceiveViewModelTests {

    // MARK: - Save

    @Test("링크의 memberId로 상대 명함을 받아 저장하고 완료 화면을 띄운다")
    func savesFetchedCard() async {
        let save = SpySaveReceivedCard()
        let sut = makeSUT(fetch: StubFetchPeerCard(card: makeCard()), save: save)

        await sut.receive(memberId: "42")

        #expect(sut.savedCard?.profile.name == "정의찬")
        #expect(save.receivedCardID == "QR-42")
        #expect(save.receivedContext == "QR 링크")
    }

    /// 명함첩 dedup 이 이 키를 보조 키로 쓴다. 스캔할 때마다 값이 달라지면 같은 사람이
    /// 여러 장으로 쌓인다.
    @Test("명함첩 키는 memberId에서 결정적으로 만들어진다")
    func cardIDIsDeterministic() {
        #expect(CardLinkReceiveViewModel.cardID(memberId: "42") == "QR-42")
        #expect(
            CardLinkReceiveViewModel.cardID(memberId: "42")
                == CardLinkReceiveViewModel.cardID(memberId: "42")
        )
    }

    @Test("내 memberId를 저장 UseCase에 넘겨 자기 명함을 거를 수 있게 한다")
    func passesOwnerMemberId() async {
        let save = SpySaveReceivedCard()
        let sut = makeSUT(save: save, ownerMemberId: "7")

        await sut.receive(memberId: "42")

        #expect(save.receivedOwnerMemberId == "7")
    }

    // MARK: - Own Card

    /// 저장 UseCase 는 자기 명함이면 `nil` 을 준다. 그대로 두면 스캔했는데 아무 일도
    /// 일어나지 않아 고장으로 읽힌다.
    @Test("자기 QR을 찍으면 완료 화면 대신 이유를 알린다")
    func ownCardIsExplained() async {
        let sut = makeSUT(save: SpySaveReceivedCard(result: nil))

        await sut.receive(memberId: "7")

        #expect(sut.savedCard == nil)
        #expect(sut.alertPrompt?.title == "내 명함이에요")
    }

    // MARK: - Failure

    @Test("조회에 실패하면 완료 화면을 띄우지 않는다")
    func fetchFailureShowsNoCompletion() async {
        let sut = makeSUT(fetch: StubFetchPeerCard(error: StubError.boom))

        await sut.receive(memberId: "42")

        #expect(sut.savedCard == nil)
        #expect(sut.alertPrompt == nil)
    }

    @Test("저장에 실패하면 완료 화면을 띄우지 않는다")
    func saveFailureShowsNoCompletion() async {
        let sut = makeSUT(save: SpySaveReceivedCard(error: StubError.boom))

        await sut.receive(memberId: "42")

        #expect(sut.savedCard == nil)
    }

    // MARK: - Reentrancy

    /// 링크가 연달아 들어오면(앱 복귀 + 바인딩 변경) 같은 명함을 두 번 저장하러 간다.
    @Test("처리 중에 다시 들어온 링크는 무시한다")
    func ignoresReentrantReceive() async {
        let fetch = BlockingFetchPeerCard(card: makeCard())
        let save = SpySaveReceivedCard()
        let sut = makeSUT(fetch: fetch, save: save)

        async let first: Void = sut.receive(memberId: "42")
        // 첫 호출이 조회에서 멈춘 사이 두 번째가 들어온다.
        await fetch.waitUntilStarted()
        await sut.receive(memberId: "42")
        await fetch.resume()
        await first

        #expect(save.callCount == 1)
    }

    @Test("완료 화면을 닫으면 저장된 명함을 비운다")
    func dismissClearsCompletion() async {
        let sut = makeSUT()
        await sut.receive(memberId: "42")
        #expect(sut.savedCard != nil)

        sut.dismissCompletion()

        #expect(sut.savedCard == nil)
    }
}

// MARK: - Helper

private enum StubError: Error {
    case boom
}

private func makeCard() -> MyCard {
    MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
    )
}

private func makeReceivedCard() -> ReceivedCard {
    ReceivedCard(
        id: "QR-42",
        profile: makeCard(),
        exchangedAt: Date(timeIntervalSince1970: 0),
        exchangeContext: "QR 링크"
    )
}

@MainActor
private func makeSUT(
    fetch: any FetchPeerCardUseCaseProtocol = StubFetchPeerCard(card: makeCard()),
    save: SpySaveReceivedCard = SpySaveReceivedCard(),
    ownerMemberId: String = "7"
) -> CardLinkReceiveViewModel {
    CardLinkReceiveViewModel(
        fetchPeerCard: fetch,
        saveReceivedCard: save,
        ownerMemberIdProvider: { ownerMemberId },
        errorHandler: ErrorHandler()
    )
}

// MARK: - Stub

private final class StubFetchPeerCard: FetchPeerCardUseCaseProtocol, @unchecked Sendable {

    private let card: MyCard?
    private let error: Error?

    init(card: MyCard? = nil, error: Error? = nil) {
        self.card = card
        self.error = error
    }

    func execute(memberId: String) async throws -> MyCard {
        if let error { throw error }
        return card!
    }
}

/// 첫 호출을 붙잡아 두어 재진입 시점을 만든다.
private actor BlockingFetchPeerCard: FetchPeerCardUseCaseProtocol {

    private let card: MyCard
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var resumeContinuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    init(card: MyCard) {
        self.card = card
    }

    func execute(memberId: String) async throws -> MyCard {
        hasStarted = true
        startedContinuation?.resume()
        startedContinuation = nil
        await withCheckedContinuation { resumeContinuation = $0 }
        return card
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}

private final class SpySaveReceivedCard: SaveReceivedCardUseCaseProtocol, @unchecked Sendable {

    private let result: ReceivedCard?
    private let error: Error?

    private(set) var callCount = 0
    private(set) var receivedCardID: String?
    private(set) var receivedOwnerMemberId: String?
    private(set) var receivedContext: String?

    init(result: ReceivedCard? = makeReceivedCard(), error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func execute(
        payload: ExchangePayload,
        ownerMemberId: String,
        exchangeContext: String?
    ) async throws -> ReceivedCard? {
        Issue.record("QR 링크 경로는 페이로드 진입점을 쓰지 않는다")
        return nil
    }

    func execute(
        card: MyCard,
        cardID: String,
        ownerMemberId: String,
        exchangeContext: String?
    ) async throws -> ReceivedCard? {
        callCount += 1
        receivedCardID = cardID
        receivedOwnerMemberId = ownerMemberId
        receivedContext = exchangeContext
        if let error { throw error }
        return result
    }
}
