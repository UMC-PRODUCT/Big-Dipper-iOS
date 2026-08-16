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
import BusinessCardData
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

    /// 명함 전체(ExchangePayload JSON)를 실은 QR.
    ///
    /// 제품 QR은 `umc://card/{memberId}` 딥링크만 싣고 수신 측이 프로필 API로 명함을
    /// 구성하는 설계다. 하지만 그 조회 엔드포인트가 아직 없어서, **교환 왕복 자체를
    /// 눈으로 보려면** 페이로드를 통째로 실은 QR이 필요하다. 검증 화면 한정이다.
    private(set) var qrPayloadImage: CGImage?

    /// 페이로드 QR에 실제로 실린 JSON 원문. QR 화면이 딥링크와 나란히 비교할 때 쓴다.
    private(set) var qrPayloadJSON: String?

    /// 위 JSON의 UTF-8 바이트 수. QR 격자 크기를 결정하는 값이라 화면에 그대로 노출한다.
    private(set) var qrPayloadByteCount = 0

    private(set) var scanLog: [String] = []

    /// 딥링크 조회가 진행 중인지. 스캐너는 프레임마다 같은 코드를 다시 올리므로 가드가 없으면
    /// 네트워크 요청이 중복으로 나가고 저장 순서도 보장되지 않는다.
    private var isResolvingDeepLink = false

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
                email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil,
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
        qrPayloadImage = makePayloadQR(for: card)
    }

    /// 명함 전체를 JSON으로 직렬화해 QR로 만든다 (검증 화면 전용 — 위 프로퍼티 주석 참고).
    ///
    /// 원문과 바이트 수도 함께 남긴다 — QR 화면이 딥링크와 격자 크기를 비교하는 근거다.
    private func makePayloadQR(for card: MyCard) -> CGImage? {
        qrPayloadJSON = nil
        qrPayloadByteCount = 0

        guard let payload = try? card.toExchangePayload(cardID: "QR-\(card.memberId)"),
              let data = try? payload.jsonData(),
              let json = String(data: data, encoding: .utf8) else { return nil }

        qrPayloadJSON = json
        qrPayloadByteCount = data.count
        return try? CoreImageQRCodeGenerator().generate(from: json)
    }

    /// 스캔한 문자열을 해석한다.
    ///
    /// 두 형식을 모두 받는다:
    /// - `umc://card/{memberId}` — 제품 QR. memberId 파싱까지 확인한다. 프로필 조회
    ///   엔드포인트가 아직 없어 명함 복원까지는 못 간다.
    /// - `ExchangePayload` JSON — 검증용 QR. 디코딩해 명함첩에 실제로 저장한다.
    func handleScanned(_ text: String) async {
        if let url = URL(string: text), let link = CardLink.parse(url) {
            await saveFromDeepLink(memberId: link.memberId)
            return
        }

        guard let data = text.data(using: .utf8),
              let payload = try? ExchangePayload.decode(from: data) else {
            scanLog.insert("해석 실패: 명함 QR이 아님 (\(text.prefix(40))…)", at: 0)
            return
        }

        do {
            let saved = try await provider.saveReceivedCardUseCase.execute(
                payload: payload,
                exchangeContext: "QR 스캔"
            )
            scanLog.insert("저장 완료: \(saved.profile.name) / \(saved.profile.nickname)", at: 0)
            await reloadReceivedCards()
        } catch {
            scanLog.insert("저장 실패: \(error)", at: 0)
        }
    }

    /// 딥링크 memberId로 서버에서 상대 명함을 받아 명함첩에 저장한다.
    ///
    /// `cardID`는 memberId에서 **결정적으로** 만든다 — 같은 상대를 여러 번 스캔해도 한 장으로
    /// 합쳐져야 하고, 명함첩의 dedup·삭제가 모두 이 값을 키로 쓴다.
    private func saveFromDeepLink(memberId: String) async {
        guard !isResolvingDeepLink else {
            scanLog.insert("이미 조회 중 — 중복 스캔 무시 (memberId=\(memberId))", at: 0)
            return
        }
        isResolvingDeepLink = true
        defer { isResolvingDeepLink = false }

        scanLog.insert("딥링크 인식: memberId=\(memberId) → 프로필 조회", at: 0)
        do {
            let card = try await provider.fetchPeerCardUseCase.execute(memberId: memberId)
            let saved = try await provider.saveReceivedCardUseCase.execute(
                card: card,
                cardID: Self.deepLinkCardID(memberId: memberId),
                exchangeContext: "QR 딥링크"
            )
            scanLog.insert(
                "저장 완료: \(saved.profile.name)/\(saved.profile.nickname) "
                + "· \(saved.profile.part.name) · \(saved.profile.generation)기",
                at: 0
            )
            await reloadReceivedCards()
        } catch {
            scanLog.insert("딥링크 저장 실패: \(error)", at: 0)
        }
    }

    /// 딥링크로 받은 명함의 명함첩 키. 페이로드 QR(`QR-{memberId}`)과 같은 규칙을 쓴다.
    static func deepLinkCardID(memberId: String) -> String { "QR-\(memberId)" }

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
