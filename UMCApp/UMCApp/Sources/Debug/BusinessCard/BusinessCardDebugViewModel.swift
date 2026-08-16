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

    /// 피어별 전송 상태. 임시 뷰가 탭 결과를 보여주지 못하면 실패인지 무반응인지 알 수 없다.
    private(set) var sendStates: [String: SendState] = [:]

    enum SendState: Equatable {
        case sending
        case sent
        case failed(String)
    }

    /// 이 기기에 페어링된 Wi-Fi Aware 기기 이름. 비어 있으면 교환이 성립할 수 없다.
    private(set) var pairedDeviceNames: [String] = []

    /// transport 연결 수립 로그. MPC 는 초대·수락·연결이 델리게이트로 흩어져 있어
    /// 어디서 멈췄는지 이것 없이는 볼 수 없다.
    var transportLog: [String] {
        (transport as? MPCTransport)?.diagnosticLog ?? []
    }

    /// 지금 실제로 연결된 피어. 목록에 떴다고 연결된 것은 아니다.
    var connectedPeerIDs: Set<String> {
        (transport as? MPCTransport)?.connectedPeerIDs ?? []
    }

    /// 지금 이 기기가 누구인지. 두 대를 나란히 놓고 볼 때 이게 없으면 어느 화면을 보고
    /// 있는지 알 수 없다 — 세션 식별자는 실행마다 바뀌고 명함 이름은 양쪽이 같다.
    var localPeerDescription: String {
        (transport as? MPCTransport)?.localPeerDescription ?? transportTypeName
    }

    /// 발견한 피어의 기기 모델 (`iPad16,1`). 같은 계정으로 두 대를 켜면 이름·파트·기수가
    /// 전부 같아서 이것 없이는 행을 가릴 수 없다.
    func deviceModel(for peer: DiscoveredPeer) -> String? {
        (transport as? MPCTransport)?.deviceModel(forPeerID: peer.id)
    }

    /// 진단 표시 갱신 신호.
    ///
    /// 위 `transportLog`·`connectedPeerIDs` 는 `@Observable` 이 아닌 transport 를 읽는
    /// **계산 프로퍼티**라 SwiftUI 가 변화를 알 방법이 없다. 값이 바뀌어도 화면은 그대로고,
    /// 다른 관측 프로퍼티가 바뀔 때만 우연히 다시 그려진다.
    ///
    /// 실기기에서 「연결됨 0」 과 멈춘 로그를 보고 *연결이 안 된다*고 판단했던 원인이
    /// 이것이다 — 고장난 계기를 읽고 있었다. 관측되는 값을 주기적으로 흔들어 다시 읽게 한다.
    /// 진단 전용 화면이라 폴링으로 충분하다.
    private(set) var diagnosticsTick = 0
    private var diagnosticsTask: Task<Void, Never>?

    /// transport가 삼킨 실패 원문. `peers: 0`이 "아무도 없음"인지 "브라우저 실패"인지 가른다.
    var transportError: String? {
        if let mpc = transport as? MPCTransport { return mpc.lastTransportError }
        return (transport as? WiFiAwareTransport)?.lastTransportError
    }

    /// 지금 **실제로 주입된** 방식. 토글 값과 다르면 앱을 다시 켜야 한다는 뜻이다.
    var activeChoice: NearbyTransportChoice {
        switch transport {
        case is MPCTransport:        return .multipeer
        case is WiFiAwareTransport:  return .wifiAware
        default:                     return .mock
        }
    }
    private(set) var eventLog: [String] = []
    private(set) var isExchanging = false

    let transportTypeName: String

    private let transport: NearbyTransportProtocol
    private let provider: BusinessCardUseCaseProviding
    private let receivedCardRepository: ReceivedCardRepositoryProtocol
    private var exchangeTask: Task<Void, Never>?

    // MARK: - Init

    init(container: DIContainer) {
        self.provider = container.resolve(BusinessCardUseCaseProviding.self)
        self.receivedCardRepository = container.resolve(ReceivedCardRepositoryProtocol.self)
        let resolvedTransport = container.resolve(NearbyTransportProtocol.self)
        self.transport = resolvedTransport
        self.transportTypeName = String(describing: type(of: resolvedTransport))
    }

    // MARK: - Function

    func loadAll() async {
        await reloadPairedDevices()
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

    func reloadPairedDevices() async {
        pairedDeviceNames = await WiFiAwareTransport.pairedDeviceNames()
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
        guard let card = myCard.value else {
            sendStates[peer.id] = .failed("내 명함이 아직 로드되지 않았다")
            eventLog.insert("send 불가: 내 명함 없음", at: 0)
            return
        }
        sendStates[peer.id] = .sending
        do {
            try await provider.exchangeCardsUseCase.send(myCard: card, to: peer)
            sendStates[peer.id] = .sent
        } catch {
            // 원문을 그대로 남긴다 — 연결 시간 초과인지 미발견인지 여기서 갈린다.
            sendStates[peer.id] = .failed("\(error)")
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
        sendStates.removeAll()
        eventLog.insert("세션 시작", at: 0)

        startDiagnosticsPolling()

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
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        isExchanging = false
    }

    /// 0.5초마다 진단 표시를 다시 읽게 하고, 유령 행을 걷어낸다.
    private func startDiagnosticsPolling() {
        diagnosticsTask?.cancel()
        diagnosticsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                self.diagnosticsTick &+= 1
                self.pruneLostPeers()
            }
        }
    }

    /// transport 가 더 이상 보지 못하는 행을 목록에서 지운다.
    ///
    /// transport 는 `lostPeer` 를 받지만 그걸 화면까지 나를 통로가 없었다(`ExchangeEvent` 에
    /// 소실 케이스가 없다). 그래서 상대 앱을 재실행하면 **옛 세션 식별자의 행이 그대로 남아**
    /// 기기 한 대에 「발견 2」 가 떴다. 그 유령을 탭하면 없는 기기에게 초대를 보내고
    /// 연결 타임아웃(20초)을 통째로 태운다.
    private func pruneLostPeers() {
        guard let mpc = transport as? MPCTransport else { return }
        let alive = mpc.discoveredPeerIDs
        guard peers.contains(where: { !alive.contains($0.id) }) else { return }
        let removed = peers.filter { !alive.contains($0.id) }.map(\.id)
        peers.removeAll { !alive.contains($0.id) }
        removed.forEach { sendStates[$0] = nil }
        eventLog.insert("피어 소실: \(removed.joined(separator: ", "))", at: 0)
    }

    private func handle(_ event: ExchangeEvent) {
        switch event {
        case .advertising:
            eventLog.insert("advertising", at: 0)
        case .scanning:
            eventLog.insert("scanning", at: 0)
        case .peerFound(let peer):
            // **덧붙이면 안 된다.** MPC 는 같은 피어를 다시 보고할 수 있고, transport 는
            // 매번 그대로 흘린다. append 하면 같은 id 의 행이 쌓여 기기 한 대에 「발견 2」 가
            // 뜬다 — 실기기에서 본 증상이다. 게다가 `ForEach(id: \.id)` 는 중복 id 를
            // 만나면 행을 잘못 재사용한다.
            if let index = peers.firstIndex(where: { $0.id == peer.id }) {
                // 거리는 별도 이벤트로 흐르므로 재발견 때문에 지워지면 안 된다.
                peers[index] = peer.applying(distanceMeters: peers[index].distanceMeters)
            } else {
                peers.append(peer)
                eventLog.insert("peerFound: \(peer.displayName ?? peer.id)", at: 0)
            }
        case .sent(let peer):
            eventLog.insert("sent → \(peer.displayName ?? peer.id)", at: 0)
        case .received(let card):
            eventLog.insert("received: \(card.profile.name) (id=\(card.id))", at: 0)
            Task { await reloadReceivedCards() }
        case .distanceUpdated(let peerID, let meters):
            // 로그에는 남기지 않는다 — 초당 여러 번 흘러 다른 이벤트를 덮어버린다.
            guard let index = peers.firstIndex(where: { $0.id == peerID }) else { return }
            peers[index] = peers[index].applying(distanceMeters: meters)
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
