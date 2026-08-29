//
//  CardExchangeViewModel.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import Foundation
import BusinessCardDomain
import CoreNearbyExchange
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let feature = "BusinessCard"
}

/// 근거리 명함 교환 세션 (시안 `12654:32621`).
///
/// 광고와 스캔이 한 세션으로 돌고, 발견된 피어를 목록에 쌓는다. 상대 명함이 도착하면
/// ``completedCard`` 가 채워지고 화면이 완료 시트를 띄운다.
///
/// - Important: `@MainActor` — 수신 저장이 SwiftData `mainContext` 를 탄다.
@MainActor
@Observable
public final class CardExchangeViewModel {

    // MARK: - Property

    public private(set) var myCard: Loadable<MyCard> = .idle

    /// 시안 목록의 행. 발견 순서를 유지한다.
    public private(set) var peers: [DiscoveredPeer] = []

    /// 수신·저장까지 끝난 상대 명함. 완료 화면의 유일한 입력이다.
    public private(set) var completedCard: ReceivedCard?

    /// 세션이 멈춘 사유. 목록이 영영 비는 것과 구분해 화면이 다르게 그린다.
    ///
    /// `Bool` 로 두면 「권한 거부」·「5분 만료」·「저장 실패」가 한 칸에 뭉개져 화면이
    /// 원인과 무관한 안내를 하게 된다 — 실제로 만료된 사용자에게 권한을 켜라고 했다.
    public private(set) var failure: BusinessCardError?

    /// 세션이 지금 돌고 있는지. 백그라운드 복귀 시 재개 여부를 이 값으로 가른다.
    public private(set) var isSessionRunning = false

    /// 내 명함을 이미 보낸 상대. 행에 「보냈어요」를 달아 준다.
    ///
    /// 전송은 성공해도 화면이 그대로였다 — 상대가 아직 안 받았는지 내가 잘못 눌렀는지
    /// 구분이 안 돼 같은 사람에게 계속 다시 보내게 된다.
    public private(set) var sentPeerIDs: Set<String> = []

    /// 지금 명함을 보내고 있는 상대. 탭과 완료 화면 사이에 아무 표시가 없으면
    /// 사용자는 「눌렀는데 반응이 없다」로 읽는다 (#1230).
    public private(set) var sendingPeerID: String?

    private let fetchMyCard: FetchMyCardUseCaseProtocol
    private let exchangeCards: ExchangeCardsUseCaseProtocol
    private let errorHandler: ErrorHandler

    // MARK: - Init

    public init(
        fetchMyCard: FetchMyCardUseCaseProtocol,
        exchangeCards: ExchangeCardsUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self.fetchMyCard = fetchMyCard
        self.exchangeCards = exchangeCards
        self.errorHandler = errorHandler
    }

    // MARK: - Function

    /// 내 명함을 확보한 뒤 세션을 열고 스트림이 닫힐 때까지 이벤트를 소비한다.
    ///
    /// 스트림 종료 = 세션 종료라 이 함수는 세션이 사는 동안 돌아온다. 호출부는
    /// `.task` 에 걸어 화면 수명과 묶는다.
    public func start() async {
        // 「계속 교환하기」로 재진입할 때 이전 결과가 남아 있으면 완료 화면이 곧장 다시 뜬다.
        completedCard = nil
        failure = nil
        sendingPeerID = nil
        peers = []
        sentPeerIDs = []

        let card: MyCard
        do {
            card = try await fetchMyCard.execute(forceRefresh: false)
            myCard = .loaded(card)
        } catch let error as AppError {
            myCard = .failed(error)
            return
        } catch {
            myCard = .failed(.unknown(message: error.localizedDescription))
            return
        }

        isSessionRunning = true
        for await event in exchangeCards.start(myCard: card) {
            apply(event)
        }
        isSessionRunning = false
    }

    /// 포그라운드 복귀. 세션이 이미 살아 있으면 아무 것도 하지 않는다.
    ///
    /// 확인 없이 다시 `start()` 하면 이전 세션이 도는 채로 광고가 겹쳐 붙는다.
    /// 화면에 처음 들어올 때도 `.active` 전이가 오므로 이 가드가 없으면 `.task` 가
    /// 연 세션 위에 하나가 더 얹힌다.
    public func resumeIfNeeded() async {
        guard !isSessionRunning else { return }
        await start()
    }

    public func send(to peer: DiscoveredPeer) async {
        guard let card = myCard.value, sendingPeerID == nil else { return }

        sendingPeerID = peer.id
        defer { sendingPeerID = nil }

        do {
            try await exchangeCards.send(myCard: card, to: peer)
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: Constants.feature,
                    action: "sendCard",
                    retryAction: { [weak self] in await self?.send(to: peer) }
                )
            )
        }
    }

    /// 화면 이탈·「교환 중지」. 광고를 끄고 스트림을 닫아 ``start()`` 의 루프를 끝낸다.
    public func stop() async {
        await exchangeCards.stop()
        isSessionRunning = false
    }

    public func dismissCompletion() {
        completedCard = nil
    }

    // MARK: - Private Function

    private func apply(_ event: ExchangeEvent) {
        switch event {
        case .advertising, .scanning:
            break

        case .sent(let peer):
            sentPeerIDs.insert(peer.id)

        case .peerFound(let peer):
            upsert(peer)

        case .peerLost(let peerID):
            // 남겨두면 없는 기기에게 초대를 보내고 연결 타임아웃(20초)을 통째로 태운다.
            peers.removeAll { $0.id == peerID }

        case .distanceUpdated(let peerID, let meters):
            updateDistance(peerID: peerID, meters: meters)

        case .received(let card):
            completedCard = card

        case .failed(let error):
            failure = error
        }
    }

    /// 같은 피어가 다시 발견되면 자리를 지킨 채 값만 갈아 끼운다 — 새로 쌓으면 같은
    /// 사람이 두 줄로 뜨고, 지웠다 넣으면 목록이 튄다.
    private func upsert(_ peer: DiscoveredPeer) {
        if let index = peers.firstIndex(where: { $0.id == peer.id }) {
            peers[index] = peer
        } else {
            peers.append(peer)
        }
    }

    /// 거리는 교환과 무관하게 계속 흐른다. 모르는 피어의 값은 버린다 — 발견 이벤트
    /// 없이 행을 만들면 이름도 파트도 없는 빈 줄이 생긴다.
    private func updateDistance(peerID: String, meters: Double?) {
        guard let index = peers.firstIndex(where: { $0.id == peerID }) else { return }

        peers[index] = peers[index].applying(distanceMeters: meters)
    }
}
