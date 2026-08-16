//
//  MPCTransport.swift
//  CoreNearbyExchange
//
//  Created by One on 8/16/26.
//

import Foundation
import MultipeerConnectivity
#if canImport(UIKit)
import UIKit
#endif

/// MultipeerConnectivity 기반 근거리 명함 교환 transport.
///
/// Wi-Fi Aware 대신 이걸 쓰는 이유는 **페어링**이다. Wi-Fi Aware 는 `DeviceDiscoveryUI` 로
/// 사전 페어링한 기기끼리만 연결되는데, 시안(Figma 12654:32255)이 그리는 건 *처음 만난*
/// 사람이 목록에 뜨는 화면이다. MPC 는 페어링 없이 주변을 탐색한다.
///
/// ## 3단계 구분
///
/// 이 transport 는 **발견 · 연결 · 전송을 명확히 나눈다.** 각 단계에서 오가는 정보가 다르다.
///
/// | 단계 | 오가는 것 | 동의 |
/// |---|---|---|
/// | 발견 | `discoveryInfo` — 이름·닉네임·파트·기수·아바타 | 「교환 시작」을 누른 것 |
/// | 연결 | `NearbyMessage.handshake` — NI 토큰 | 자동 (개인정보 아님) |
/// | 전송 | `NearbyMessage.card` — 명함 전체 | **행을 탭해야** |
///
/// 연결을 미리 해두는 이유는 거리 때문이다. NI 토큰(343B)은 `discoveryInfo`(Bonjour TXT)에
/// 들어가지 않아 세션이 열린 뒤에야 보낼 수 있고, 토큰이 없으면 거리를 잴 수 없다.
///
/// ## 동시성 규칙 (Wi-Fi Aware 스파이크에서 얻은 것)
/// - `continuation.finish()` 는 절대 `stateQueue` 안에서 호출하지 않는다. `onTermination` 이
///   finish 호출 스레드에서 동기 실행되므로 직렬 큐 재진입 = 확정 데드락.
/// - 맞교환 회신은 **연결당 1회**. 양쪽이 동시에 광고+탐색하는 세션 모델이라 조건이 빠지면
///   A→B→A→B… 무한 에코가 된다.
/// - 수신 페이로드가 `receive()` 구독보다 먼저 도착할 수 있어 구독 전 도착분을 버퍼링한다.
/// - DI 캐싱으로 이 인스턴스는 앱 수명 싱글톤이다. 세션 상태는 start/stop 에서 리셋한다.
public final class MPCTransport: NSObject, NearbyTransportProtocol, @unchecked Sendable {

    // MARK: - Constants

    /// Info.plist `NSBonjourServices` 선언과 반드시 같아야 한다.
    /// MPC 규칙상 15자 이하 · 영숫자와 하이픈만 · 하이픈으로 시작/끝 금지.
    public static let serviceType = "umc-card"

    private enum Constants {
        /// `discoveryInfo` 는 Bonjour TXT 레코드라 작다. 긴 값은 잘라 넣는다.
        static let maxDiscoveryValueLength = 64
        static let invitationTimeout: TimeInterval = 20
    }

    private enum DiscoveryKey {
        static let name = "n"
        static let nickname = "k"
        static let part = "p"
        static let generation = "g"
        static let avatarURL = "a"
    }

    // MARK: - Property

    public static var isSupported: Bool { true }

    private let stateQueue = DispatchQueue(label: "dev.umc.nearby.mpc")

    private let localPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// 내 명함. 상대가 탭해서 요청하면 이걸 보낸다.
    private var myCard: ExchangePayload?
    /// 연결 직후 보낼 핸드셰이크. 호출부가 NI 토큰을 채워 넣는다.
    private var myHandshake: NearbyHandshake?

    /// 발견된 피어. `MCPeerID.displayName` 이 아니라 우리가 만든 안정 id 로 키를 잡는다.
    private var peersByID: [String: MCPeerID] = [:]
    /// 맞교환 회신을 이미 보낸 피어 — 무한 에코 차단.
    private var repliedPeerIDs = Set<String>()
    /// `receive()` 구독 전에 도착한 명함.
    private var pendingPayloads: [ExchangePayload] = []

    private var peerContinuation: AsyncStream<DiscoveredPeer>.Continuation?
    private var receiveContinuation: AsyncStream<ExchangePayload>.Continuation?

    /// 상대에게서 받은 NI 토큰. 레인징 조율 계층이 꺼내 쓴다.
    private var handshakesByPeerID: [String: NearbyHandshake] = [:]

    /// 마지막 실패 원문. 스트림에 에러 채널이 없어 여기 남긴다 (Wi-Fi Aware 와 같은 이유).
    private var _lastTransportError: String?

    public var lastTransportError: String? {
        stateQueue.sync { _lastTransportError }
    }

    // MARK: - Init

    /// - Parameter displayName: `MCPeerID` 표시 이름. 기기 이름이 그대로 노출되지 않도록
    ///   호출부가 익명 값을 넘길 수 있다. 실제 신원은 `discoveryInfo` 가 나른다.
    public init(displayName: String = NearbyPeerDisplayName.current) {
        self.localPeerID = MCPeerID(displayName: displayName)
        super.init()
    }

    deinit {
        tearDown()
    }

    // MARK: - Advertising

    public func startAdvertising(card: ExchangePayload) async throws {
        resetSessionState()

        let session = MCSession(
            peer: localPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self

        let advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: Self.discoveryInfo(from: card),
            serviceType: Self.serviceType
        )
        advertiser.delegate = self

        stateQueue.sync {
            self.session = session
            self.advertiser = advertiser
            self.myCard = card
        }
        advertiser.startAdvertisingPeer()
    }

    /// 세션 종료 지점. 광고·탐색을 멈추고 수신 스트림을 닫는다.
    public func stopAdvertising() async {
        let (advertiser, browser, session) = stateQueue.sync {
            (self.advertiser, self.browser, self.session)
        }
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()

        stateQueue.sync {
            self.advertiser = nil
            self.browser = nil
            self.session = nil
            self.myCard = nil
        }
        // finish 는 반드시 락 밖 — onTermination 이 같은 직렬 큐에 재진입하면 데드락.
        takeReceiveContinuation()?.finish()
        resetSessionState()
    }

    // MARK: - Scanning

    public func startScanning() -> AsyncStream<DiscoveredPeer> {
        AsyncStream { continuation in
            stateQueue.sync { peerContinuation = continuation }
            continuation.onTermination = { [weak self] _ in
                // sync 금지 — 이 핸들러는 finish() 호출 스레드에서 동기 실행된다.
                self?.stateQueue.async {
                    self?.browser?.stopBrowsingForPeers()
                    self?.browser = nil
                    self?.peerContinuation = nil
                }
            }

            let browser = MCNearbyServiceBrowser(
                peer: localPeerID,
                serviceType: Self.serviceType
            )
            browser.delegate = self
            stateQueue.sync { self.browser = browser }
            browser.startBrowsingForPeers()
        }
    }

    // MARK: - Data Transfer

    /// 명함 전체를 보낸다. **사용자가 행을 탭했을 때만** 호출된다.
    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        let (session, peerID) = stateQueue.sync { (self.session, peersByID[peer.id]) }
        guard let session, let peerID else {
            throw NearbyError.invalidPayload("발견되지 않은 피어: \(peer.id)")
        }
        guard session.connectedPeers.contains(peerID) else {
            throw NearbyError.transportFailure(
                underlying: NearbyError.invalidPayload("아직 연결되지 않은 피어")
            )
        }
        try sendMessage(.card(payload), to: [peerID], session: session)
    }

    public func receive() -> AsyncStream<ExchangePayload> {
        AsyncStream { continuation in
            // 구독 전에 도착한 명함을 먼저 흘린다 — 광고/구독 순서에 의존하지 않는다.
            let buffered = stateQueue.sync { () -> [ExchangePayload] in
                receiveContinuation = continuation
                let pending = pendingPayloads
                pendingPayloads.removeAll()
                return pending
            }
            for payload in buffered {
                continuation.yield(payload)
            }
            continuation.onTermination = { [weak self] _ in
                self?.stateQueue.async { self?.receiveContinuation = nil }
            }
        }
    }

    // MARK: - Handshake

    /// 연결 직후 보낼 핸드셰이크를 설정한다. NI 토큰은 호출부(레인징 조율 계층)가 만든다.
    public func setHandshake(_ handshake: NearbyHandshake) {
        stateQueue.sync { myHandshake = handshake }
    }

    /// 상대에게서 받은 핸드셰이크. 레인징 조율 계층이 NI 토큰을 꺼내 쓴다.
    public func handshake(forPeerID peerID: String) -> NearbyHandshake? {
        stateQueue.sync { handshakesByPeerID[peerID] }
    }

    // MARK: - Private Function

    /// 명함에서 발견 목록에 필요한 최소 정보만 뽑는다.
    ///
    /// Bonjour TXT 레코드라 크기가 작아 **이메일·외부 링크는 넣지 않는다.** 넣을 자리도 없고,
    /// 동의 전에 흐르는 정보이므로 넣어서도 안 된다.
    static func discoveryInfo(from card: ExchangePayload) -> [String: String] {
        var info: [String: String] = [
            DiscoveryKey.name: truncated(card.name),
            DiscoveryKey.nickname: truncated(card.nickname),
            DiscoveryKey.part: truncated(card.part),
            DiscoveryKey.generation: truncated(card.generation),
        ]
        if let avatarURL = card.avatarURL, !avatarURL.isEmpty {
            info[DiscoveryKey.avatarURL] = truncated(avatarURL)
        }
        return info
    }

    private static func truncated(_ value: String) -> String {
        String(value.prefix(Constants.maxDiscoveryValueLength))
    }

    /// `discoveryInfo` 를 발견 피어로 옮긴다. 값이 없으면 표시 이름만 남는다.
    private func makePeer(from peerID: MCPeerID, info: [String: String]?) -> DiscoveredPeer {
        let name = info?[DiscoveryKey.name]
        let nickname = info?[DiscoveryKey.nickname]
        let displayName: String? = {
            guard let name, let nickname else { return name ?? peerID.displayName }
            return "\(name)/\(nickname)"
        }()

        return DiscoveredPeer(
            id: peerID.displayName,
            cardUUIDPrefix: Data(),
            version: UInt8(clamping: ExchangePayload.currentVersion),
            flags: 0,
            displayName: displayName,
            part: info?[DiscoveryKey.part],
            generation: info?[DiscoveryKey.generation],
            avatarURL: info?[DiscoveryKey.avatarURL]
        )
    }

    private func sendMessage(
        _ message: NearbyMessage,
        to peers: [MCPeerID],
        session: MCSession
    ) throws {
        guard !peers.isEmpty else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try session.send(try encoder.encode(message), toPeers: peers, with: .reliable)
        } catch {
            recordError("send", error)
            throw NearbyError.transportFailure(underlying: error)
        }
    }

    private func recordError(_ stage: String, _ error: Error) {
        stateQueue.sync { _lastTransportError = "[\(stage)] \(error)" }
    }

    private func takeReceiveContinuation() -> AsyncStream<ExchangePayload>.Continuation? {
        stateQueue.sync {
            let current = receiveContinuation
            receiveContinuation = nil
            return current
        }
    }

    private func takePeerContinuation() -> AsyncStream<DiscoveredPeer>.Continuation? {
        stateQueue.sync {
            let current = peerContinuation
            peerContinuation = nil
            return current
        }
    }

    private func resetSessionState() {
        stateQueue.sync {
            _lastTransportError = nil
            peersByID.removeAll()
            repliedPeerIDs.removeAll()
            pendingPayloads.removeAll()
            handshakesByPeerID.removeAll()
        }
    }

    private func tearDown() {
        stateQueue.sync {
            advertiser?.stopAdvertisingPeer()
            browser?.stopBrowsingForPeers()
            session?.disconnect()
            advertiser = nil
            browser = nil
            session = nil
        }
        takePeerContinuation()?.finish()
        takeReceiveContinuation()?.finish()
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MPCTransport: MCNearbyServiceAdvertiserDelegate {

    /// 초대를 **자동 수락**한다.
    ///
    /// 시안에 수락 화면이 없다. 양쪽 모두 「교환 시작」을 눌러 탐색 화면에 있는 상태가 동의로
    /// 간주된다. 수락해도 **명함은 나가지 않는다** — 세션만 열리고, 오가는 건 NI 토큰뿐이다.
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let session = stateQueue.sync { self.session }
        invitationHandler(session != nil, session)
    }

    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: any Error
    ) {
        recordError("advertise", error)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MPCTransport: MCNearbyServiceBrowserDelegate {

    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let peer = makePeer(from: peerID, info: info)
        let (session, shouldInvite) = stateQueue.sync { () -> (MCSession?, Bool) in
            let isNew = peersByID[peer.id] == nil
            peersByID[peer.id] = peerID
            peerContinuation?.yield(peer)
            return (self.session, isNew)
        }

        // 발견 즉시 연결한다 — NI 토큰을 주고받으려면 세션이 필요하고, 토큰이 없으면
        // 거리를 잴 수 없다. 명함은 여전히 사용자가 탭해야 나간다.
        guard shouldInvite, let session else { return }
        browser.invitePeer(
            peerID,
            to: session,
            withContext: nil,
            timeout: Constants.invitationTimeout
        )
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        stateQueue.sync {
            peersByID[peerID.displayName] = nil
            handshakesByPeerID[peerID.displayName] = nil
            repliedPeerIDs.remove(peerID.displayName)
        }
    }

    public func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: any Error
    ) {
        recordError("browse", error)
        takePeerContinuation()?.finish()
    }
}

// MARK: - MCSessionDelegate

extension MPCTransport: MCSessionDelegate {

    public func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        guard state == .connected else { return }

        // 연결되면 핸드셰이크를 보낸다. 여기 실리는 건 NI 토큰과 미리보기뿐 — 명함이 아니다.
        let handshake = stateQueue.sync { myHandshake }
        guard let handshake else { return }
        try? sendMessage(.handshake(handshake), to: [peerID], session: session)
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let message = try? decoder.decode(NearbyMessage.self, from: data) else {
            recordError("decode", NearbyError.invalidPayload("알 수 없는 메시지"))
            return
        }

        switch message {
        case .handshake(let handshake):
            stateQueue.sync { handshakesByPeerID[peerID.displayName] = handshake }

        case .card(let payload):
            let reply = stateQueue.sync { () -> ExchangePayload? in
                if let continuation = receiveContinuation {
                    continuation.yield(payload)
                } else {
                    pendingPayloads.append(payload)   // 구독 전 도착분
                }
                // 맞교환은 **연결당 1회**. 빠지면 A→B→A→B 무한 에코가 된다.
                guard repliedPeerIDs.insert(peerID.displayName).inserted else { return nil }
                return myCard
            }
            if let reply {
                try? sendMessage(.card(reply), to: [peerID], session: session)
            }
        }
    }

    // MARK: 미사용 델리게이트 — 이 transport 는 스트림·리소스를 쓰지 않는다

    public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {}
}

// MARK: - Device Name

/// `MCPeerID` 표시 이름 기본값.
///
/// MPC 는 표시 이름을 63바이트로 제한한다. 실제 신원은 `discoveryInfo` 가 나르므로
/// 이 값은 세션 안에서 피어를 구분하는 용도로만 쓴다.
public enum NearbyPeerDisplayName {
    public static var current: String {
        #if canImport(UIKit)
        return String(UIDevice.current.name.prefix(63))
        #else
        return String(ProcessInfo.processInfo.hostName.prefix(63))
        #endif
    }
}

