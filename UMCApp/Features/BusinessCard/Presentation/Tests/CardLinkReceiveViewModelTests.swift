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

    @Test("동의하면 링크의 memberId로 받은 명함을 저장하고 완료 화면을 띄운다")
    func savesFetchedCard() async {
        let save = SpySaveReceivedCard()
        let sut = makeSUT(fetch: StubFetchPeerCard(card: makeCard()), save: save)

        await sut.receiveAndConsent(link: CardLink(memberId: "42"))

        #expect(sut.savedCard?.profile.name == "정의찬")
        #expect(save.receivedCardID == "QR-42")
        // 출처는 맥락 메모가 아니라 ``ExchangeMethod`` 가 들고 간다 (#1227).
        #expect(save.receivedContext == nil)
        #expect(save.receivedMethod == .qrLink)
    }

    // MARK: - Consent (#1226)

    /// 남의 QR 이 찍히는 순간 연락처가 말없이 쌓이면 안 된다.
    @Test("동의를 받기 전에는 명함첩에 아무것도 넣지 않는다")
    func asksBeforeSaving() async {
        let save = SpySaveReceivedCard()
        let sut = makeSUT(save: save)

        await sut.receive(link: CardLink(memberId: "42"))

        #expect(save.callCount == 0)
        #expect(sut.savedCard == nil)
        #expect(sut.alertPrompt?.title == "정의찬님의 명함을 저장할까요?")
    }

    @Test("동의를 취소하면 저장하지 않는다")
    func cancelSkipsSave() async {
        let save = SpySaveReceivedCard()
        let sut = makeSUT(save: save)

        await sut.receive(link: CardLink(memberId: "42"))
        sut.alertPrompt?.negativeBtnAction?()
        sut.alertPrompt = nil

        #expect(save.callCount == 0)
        #expect(sut.savedCard == nil)
    }

    // MARK: - Expiry (#1226)

    /// 만료 확인이 조회보다 앞이라 죽은 링크로 서버를 두드리지 않는다.
    @Test("만료된 링크는 조회하지 않고 이유를 알린다")
    func expiredLinkIsRejected() async {
        let fetch = StubFetchPeerCard(card: makeCard())
        let save = SpySaveReceivedCard()
        let sut = makeSUT(fetch: fetch, save: save)

        let expired = CardLink(memberId: "42", expiresAt: .distantPast)
        await sut.receive(link: expired)

        #expect(fetch.callCount == 0)
        #expect(save.callCount == 0)
        #expect(sut.alertPrompt?.title == "만료된 QR이에요")
    }

    /// Android 가 굽는 링크와 `exp` 도입 전 QR 에는 만료가 없다 — 통째로 막으면 안 된다.
    @Test("만료가 없는 링크는 그대로 받는다")
    func linkWithoutExpiryIsAccepted() async {
        let sut = makeSUT()

        await sut.receiveAndConsent(link: CardLink(memberId: "42"))

        #expect(sut.savedCard != nil)
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

        await sut.receiveAndConsent(link: CardLink(memberId: "42"))

        #expect(save.receivedOwnerMemberId == "7")
    }

    // MARK: - Own Card

    /// 스캔했는데 아무 일도 일어나지 않으면 고장으로 읽힌다. 「내 명함을 저장할까요?」를
    /// 묻는 것도 이상하므로 동의 단계에 들어가기 전에 갈라진다.
    @Test("자기 QR을 찍으면 동의를 묻지 않고 이유를 알린다")
    func ownCardIsExplained() async {
        let save = SpySaveReceivedCard(result: nil)
        let sut = makeSUT(save: save, ownerMemberId: "7")

        await sut.receive(link: CardLink(memberId: "7"))

        #expect(sut.savedCard == nil)
        #expect(save.callCount == 0)
        #expect(sut.alertPrompt?.title == "내 명함이에요")
    }

    /// 소유자 판정의 정본은 저장 UseCase 다. 사전 확인이 놓쳐도 안내는 나와야 한다.
    @Test("저장 UseCase가 자기 명함이라고 판정해도 이유를 알린다")
    func ownCardFromUseCaseIsExplained() async {
        let sut = makeSUT(save: SpySaveReceivedCard(result: nil))

        await sut.receiveAndConsent(link: CardLink(memberId: "42"))

        #expect(sut.savedCard == nil)
        #expect(sut.alertPrompt?.title == "내 명함이에요")
    }

    // MARK: - Failure

    @Test("조회에 실패하면 완료 화면을 띄우지 않는다")
    func fetchFailureShowsNoCompletion() async {
        let sut = makeSUT(fetch: StubFetchPeerCard(error: StubError.boom))

        await sut.receive(link: CardLink(memberId: "42"))

        #expect(sut.savedCard == nil)
        #expect(sut.alertPrompt == nil)
    }

    @Test("저장에 실패하면 완료 화면을 띄우지 않는다")
    func saveFailureShowsNoCompletion() async {
        let sut = makeSUT(save: SpySaveReceivedCard(error: StubError.boom))

        await sut.receiveAndConsent(link: CardLink(memberId: "42"))

        #expect(sut.savedCard == nil)
    }

    // MARK: - Reentrancy

    /// 링크가 연달아 들어오면(앱 복귀 + 바인딩 변경) 같은 명함을 두 번 저장하러 간다.
    @Test("처리 중에 다시 들어온 링크는 무시한다")
    func ignoresReentrantReceive() async {
        let fetch = BlockingFetchPeerCard(card: makeCard())
        let save = SpySaveReceivedCard()
        let sut = makeSUT(fetch: fetch, save: save)

        async let first: Void = sut.receive(link: CardLink(memberId: "42"))
        // 첫 호출이 조회에서 멈춘 사이 두 번째가 들어온다.
        await fetch.waitUntilStarted()
        await sut.receive(link: CardLink(memberId: "42"))
        await fetch.resume()
        await first

        let fetchCount = await fetch.callCount
        #expect(fetchCount == 1)
        #expect(save.callCount == 0)
    }

    @Test("완료 화면을 닫으면 저장된 명함을 비운다")
    func dismissClearsCompletion() async {
        let sut = makeSUT()
        await sut.receiveAndConsent(link: CardLink(memberId: "42"))
        #expect(sut.savedCard != nil)

        sut.dismissCompletion()

        #expect(sut.savedCard == nil)
    }
}

// MARK: - Helper

private extension CardLinkReceiveViewModel {
    /// 링크를 받고 동의 버튼까지 눌러 저장이 끝나기를 기다린다 (#1226).
    func receiveAndConsent(link: CardLink) async {
        await receive(link: link)
        alertPrompt?.positiveBtnAction?()
        await saveTask?.value
    }
}

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

    private(set) var callCount = 0

    init(card: MyCard? = nil, error: Error? = nil) {
        self.card = card
        self.error = error
    }

    func execute(memberId: String) async throws -> MyCard {
        callCount += 1
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

    private(set) var callCount = 0

    init(card: MyCard) {
        self.card = card
    }

    func execute(memberId: String) async throws -> MyCard {
        callCount += 1
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
    private(set) var receivedMethod: ExchangeMethod?

    init(result: ReceivedCard? = makeReceivedCard(), error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func execute(
        payload: ExchangePayload,
        ownerMemberId: String,
        exchangeContext: String?,
        exchangeMethod: ExchangeMethod
    ) async throws -> ReceivedCard? {
        Issue.record("QR 링크 경로는 페이로드 진입점을 쓰지 않는다")
        return nil
    }

    func execute(
        card: MyCard,
        cardID: String,
        ownerMemberId: String,
        exchangeContext: String?,
        exchangeMethod: ExchangeMethod
    ) async throws -> ReceivedCard? {
        callCount += 1
        receivedCardID = cardID
        receivedOwnerMemberId = ownerMemberId
        receivedContext = exchangeContext
        receivedMethod = exchangeMethod
        if let error { throw error }
        return result
    }
}
