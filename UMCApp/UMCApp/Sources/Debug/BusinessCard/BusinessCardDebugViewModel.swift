//
//  BusinessCardDebugViewModel.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import CoreGraphics
import CoreNearbyExchange
import Foundation
import Observation
import BusinessCardDomain
import BusinessCardPresentation
import UMCFoundation

/// 명함 기능 계층 검증 화면의 상태. 제품 ViewModel이 아니라 진단 도구다.
@Observable
final class BusinessCardDebugViewModel {

    // MARK: - Property

    var myCard: Loadable<MyCard> = .idle
    var activityStat: ActivityStat = .empty
    var receivedCards: Loadable<[ReceivedCard]> = .idle
    var receivedCardCount: Int = 0
    var searchText: String = ""

    private(set) var qrImage: CGImage?
    private(set) var qrPayload: String = "—"
    private(set) var payloadCheck: [String] = []

    private(set) var peers: [DiscoveredPeer] = []
    private(set) var eventLog: [String] = []
    private(set) var isExchanging = false

    let transportTypeName: String

    private let provider: BusinessCardUseCaseProviding
    private let receivedCardRepository: ReceivedCardRepositoryProtocol
    private var exchangeTask: Task<Void, Never>?

    // MARK: - Init

    init(container: DIContainer) {
        self.provider = container.resolve(BusinessCardUseCaseProviding.self)
        self.receivedCardRepository = container.resolve(ReceivedCardRepositoryProtocol.self)
        self.transportTypeName = String(
            describing: type(of: container.resolve(NearbyTransportProtocol.self))
        )
    }

    // MARK: - Function

    func loadAll() async {
        await reloadMyCard(forceRefresh: false)
        await reloadActivityStat()
        await reloadReceivedCards()
    }

    func reloadMyCard(forceRefresh: Bool) async {
        myCard = .loading
        do {
            let card = try await provider.fetchMyCardUseCase.execute(forceRefresh: forceRefresh)
            myCard = .loaded(card)
            makeQR(for: card)
            runPayloadRoundtrip(for: card)
        } catch let error as AppError {
            myCard = .failed(error)
        } catch {
            myCard = .failed(.unknown(message: error.localizedDescription))
        }
    }

    func reloadActivityStat() async {
        activityStat = await provider.fetchActivityStatUseCase.execute()
    }

    func reloadReceivedCards() async {
        receivedCards = .loading
        do {
            let query = searchText.isEmpty ? nil : searchText
            receivedCards = .loaded(
                try await provider.fetchReceivedCardsUseCase.execute(query: query)
            )
            receivedCardCount = try await receivedCardRepository.count()
        } catch let error as AppError {
            receivedCards = .failed(error)
        } catch {
            receivedCards = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 교환 없이 저장 경로만 확인하기 위한 합성 명함. 파트를 매번 바꿔 색 구분도 본다.
    func saveSampleCard() async {
        let index = receivedCardCount
        let parts = UMCPartType.allCases
        let part = parts[index % parts.count]
        do {
            let payload = try ExchangePayload(
                cardID: "DEBUG-\(index)",
                name: "샘플\(index)",
                nickname: "닉\(index)",
                part: part.apiValue,
                generation: "1\(index % 3)",
                university: "테스트대학교",
                email: nil, github: nil, blog: nil, avatarURL: nil,
                memberNo: "\(9000 + index)",
                cardLink: "umc://card/\(9000 + index)"
            )
            _ = try await provider.saveReceivedCardUseCase.execute(
                payload: payload,
                exchangeContext: "디버그 저장"
            )
            await reloadReceivedCards()
        } catch {
            eventLog.insert("샘플 저장 실패: \(error)", at: 0)
        }
    }

    func delete(id: String) async {
        do {
            try await provider.deleteReceivedCardUseCase.execute(id: id)
            await reloadReceivedCards()
        } catch {
            eventLog.insert("삭제 실패: \(error)", at: 0)
        }
    }

    func toggleExchange() async {
        if isExchanging {
            await stopExchange()
        } else {
            await startExchange()
        }
    }

    func send(to peer: DiscoveredPeer) async {
        guard let card = myCard.value else { return }
        do {
            try await provider.exchangeCardsUseCase.send(myCard: card, to: peer)
        } catch {
            eventLog.insert("send 실패: \(error)", at: 0)
        }
    }

    // MARK: - Private Function

    private func startExchange() async {
        guard let card = myCard.value else {
            eventLog.insert("내 명함이 없어 교환을 시작할 수 없다", at: 0)
            return
        }
        isExchanging = true
        peers = []
        eventLog.insert("세션 시작", at: 0)

        let stream = provider.exchangeCardsUseCase.start(myCard: card)
        exchangeTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                self.handle(event)
            }
            self?.isExchanging = false
            self?.eventLog.insert("스트림 종료", at: 0)
        }
    }

    private func stopExchange() async {
        await provider.exchangeCardsUseCase.stop()
        exchangeTask?.cancel()
        exchangeTask = nil
        isExchanging = false
    }

    private func handle(_ event: ExchangeEvent) {
        switch event {
        case .advertising:
            eventLog.insert("advertising", at: 0)
        case .scanning:
            eventLog.insert("scanning", at: 0)
        case .peerFound(let peer):
            peers.append(peer)
            eventLog.insert("peerFound: \(peer.displayName ?? peer.id)", at: 0)
        case .sent(let peer):
            eventLog.insert("sent → \(peer.displayName ?? peer.id)", at: 0)
        case .received(let card):
            eventLog.insert("received: \(card.profile.name) (id=\(card.id))", at: 0)
            Task { await reloadReceivedCards() }
        case .failed(let error):
            eventLog.insert("failed: \(error.localizedDescription)", at: 0)
        }
    }

    private func makeQR(for card: MyCard) {
        qrPayload = card.qrPayload
        qrImage = try? provider.generateCardQRUseCase.execute(for: card)
    }

    /// 명함 → 페이로드 → JSON → 디코딩 → 명함 복원을 실제로 돌려 결과를 문자열로 남긴다.
    private func runPayloadRoundtrip(for card: MyCard) {
        var lines: [String] = []
        do {
            let payload = try card.toExchangePayload(cardID: "DEBUG-RT")
            let data = try payload.jsonData()
            lines.append("version: \(payload.version) (current \(ExchangePayload.currentVersion))")
            lines.append("json bytes: \(data.count)")

            let decoded = try ExchangePayload.decode(from: data)
            lines.append("decode 왕복 동일: \(decoded == payload)")

            let restored = MyCard(payload: decoded)
            lines.append("복원 memberId: \(restored.memberId) (원본 \(card.memberId))")
            lines.append("복원 part: \(restored.part.apiValue) (원본 \(card.part.apiValue))")
            lines.append("cardLink: \(decoded.cardLink)")
        } catch {
            lines.append("왕복 실패: \(error)")
        }
        payloadCheck = lines
    }
}
#endif
