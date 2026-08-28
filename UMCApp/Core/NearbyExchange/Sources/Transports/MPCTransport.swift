//
//  MPCTransport.swift
//  CoreNearbyExchange
//
//  Created by One on 8/16/26.
//

import Foundation
import MultipeerConnectivity

// MARK: - MPCTransport

/// MultipeerConnectivity 기반 근거리 명함 교환 transport.
///
/// Wi-Fi Aware 대신 이걸 쓰는 이유는 **페어링**이다. Wi-Fi Aware 는 `DeviceDiscoveryUI` 로
/// 사전 페어링한 기기끼리만 연결되는데, 시안(Figma 12654:32255)이 그리는 건 *처음 만난*
/// 사람이 목록에 뜨는 화면이다. MPC 는 페어링 없이 주변을 탐색한다.
///
/// ## 3단계 구분
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
        /// 세션 식별자 길이. 충돌 확률과 TXT 레코드 크기의 절충.
        static let sessionIDLength = 12
        /// 미연결 피어 재초대 주기. `foundPeer` 가 피어당 한 번만 불리므로
        /// 이것 없이는 유실된 초대를 되살릴 방법이 없다.
        static let connectRetryInterval: TimeInterval = 3
    }

    private enum DiscoveryKey {
        /// 세션 식별자. **피어를 가르는 유일한 키다** (아래 `localSessionID` 주석 참고).
        static let sessionID = "s"
        static let name = "n"
        static let nickname = "k"
        static let part = "p"
        static let generation = "g"
        static let avatarURL = "a"
        /// 기기 하드웨어 식별자. **검증용이라 DEBUG 에서만 실어 보낸다.**
        static let device = "d"
    }

    // MARK: - Property

    public static var isSupported: Bool { true }

    /// 이 실행에서 나를 가리키는 임의 식별자.
    ///
    /// `MCPeerID.displayName` 을 키로 쓸 수 없다. **iOS 16부터 `UIDevice.name` 은 별도
    /// entitlement 없이는 기기 이름을 주지 않고 `"iPhone"` 같은 기종명을 돌려준다.** 그러면
    /// 주변 기기가 전부 같은 이름이 되어 3대째부터 서로를 구분하지 못한다. 2대로 검증하면
    /// 각자 상대가 하나뿐이라 이 결함이 드러나지 않는다.
    ///
    /// 매 실행 새로 만든다 — 기기를 가로질러 추적할 수 있는 값이 되면 안 된다.
    private let localSessionID: String

    private let stateQueue = DispatchQueue(label: "dev.umc.nearby.mpc")

    private let localPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// 내 명함. 맞교환 회신에 쓴다.
    private var myCard: ExchangePayload?

    /// 세션 식별자 → MPC 피어.
    ///
    /// 역방향 딕셔너리는 두지 않는다. `MCPeerID.displayName` 이 곧 세션 식별자이기 때문이다
    /// (`localPeerID` 를 그렇게 만든다). 딕셔너리로 되찾으면 **발견 경로로만 채워져서**,
    /// 초대를 수락해 연결된 피어는 조회에 실패한다 — 실기기에서 한쪽만 「연결됨 0」 으로
    /// 보이던 원인이 이것이었다.
    private var peersBySessionID: [String: MCPeerID] = [:]
    /// 발견 정보 보관 — 연결 이후에도 목록 행을 다시 그릴 수 있어야 한다.
    private var discoveredPeers: [String: DiscoveredPeer] = [:]
    /// 피어의 기기 하드웨어 식별자. 검증 화면이 폰과 패드를 가르는 데만 쓴다.
    private var deviceModels: [String: String] = [:]
    /// 맞교환 회신을 이미 보낸 피어 — 무한 에코 차단.
    private var repliedSessionIDs = Set<String>()
    /// 지금 연결 시도 중인 피어. **초대가 겹치지 않게 막는 값이다** — 이미 시도 중인
    /// 피어를 다시 초대하면 MPC 가 같은 쌍에 두 연결을 겹쳐 받고 둘 다 실패한다.
    private var connectingSessionIDs = Set<String>()
    /// 미연결 피어 재초대 타이머. 핸들러가 `stateQueue` 에서 실행되므로 그 안에서는
    /// `stateQueue.sync` 를 부르면 안 된다 (직렬 큐 재진입 = 데드락).
    private var connectTimer: DispatchSourceTimer?
    /// `receive()` 구독 전에 도착한 명함.
    private var pendingPayloads: [ExchangePayload] = []

    private var peerContinuation: AsyncStream<DiscoveredPeer>.Continuation?
    private var receiveContinuation: AsyncStream<ExchangePayload>.Continuation?

    /// 핸드셰이크를 만들고 받는 쪽 (레인징 조율 계층). 없으면 핸드셰이크를 주고받지 않는다.
    private weak var handshakeProvider: (any NearbyHandshakeProviding)?

    /// 마지막 실패 원문. 스트림에 에러 채널이 없어 여기 남긴다 (Wi-Fi Aware 와 같은 이유).
    private var _lastTransportError: String?

    /// 연결 수립 과정 로그. MPC 는 초대·수락·연결이 전부 델리게이트로 흩어져 있어
    /// 어디서 멈췄는지 밖에서 볼 수 없다. 최신순으로 쌓는다.
    private var _log: [String] = []

    public var lastTransportError: String? {
        stateQueue.sync { _lastTransportError }
    }

    /// 진단 로그 (최신순, 최대 40줄).
    public var diagnosticLog: [String] {
        stateQueue.sync { _log }
    }

    /// 지금 **살아 있다고 보는** 피어의 세션 식별자.
    ///
    /// 화면 목록이 여기에 없는 행을 들고 있으면 유령이다. 앱을 강제 종료하면 Bonjour
    /// goodbye 가 나가지 않아 상대 목록에 옛 광고가 TTL 만큼 남는데, 그 행을 탭하면 없는
    /// 기기에게 초대를 보내고 타임아웃까지 그대로 태운다.
    public var discoveredPeerIDs: Set<String> {
        stateQueue.sync { Set(discoveredPeers.keys) }
    }

    /// 지금 세션에 연결된 피어의 세션 식별자.
    public var connectedPeerIDs: Set<String> {
        stateQueue.sync {
            guard let session else { return [] }
            return Set(session.connectedPeers.map(\.displayName))
        }
    }

    // MARK: - Init

    public override init() {
        let sessionID = Self.makeSessionID()
        self.localSessionID = sessionID
        // 표시 이름에도 같은 값을 쓴다. 기기 이름을 노출하지 않고, MPC 내부 로그에서도
        // 피어가 구분된다. 사람이 읽는 이름은 discoveryInfo 가 나른다.
        self.localPeerID = MCPeerID(displayName: sessionID)
        super.init()
    }

    deinit {
        tearDown()
    }

    // MARK: - Configuration

    /// 레인징 조율 계층을 연결한다 (``NearbyTransportProtocol`` 요구사항).
    /// 설정하지 않으면 거리 없이 발견·교환만 동작한다.
    public func setHandshakeProvider(_ provider: any NearbyHandshakeProviding) {
        stateQueue.sync { handshakeProvider = provider }
    }

    // MARK: - Advertising

    public func startAdvertising(card: ExchangePayload) async throws {
        // `stopAdvertising()` 을 부르면 안 된다 — 그 안의 `takeReceiveContinuation()?.finish()`
        // 가 **직전에 등록된 수신 스트림을 닫는다.** UseCase 는 `receive()` 를 먼저 구독하고
        // 곧바로 여기를 부르므로(선착 페이로드를 놓치지 않으려는 순서다), 여기서 수신
        // continuation 을 건드리면 상대 명함이 영영 도착하지 않는다.
        // 전송은 되는데 수신만 안 되는 증상으로 나타난다.
        tearDownChannels()

        let session = MCSession(
            peer: localPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self

        let advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: Self.discoveryInfo(from: card, sessionID: localSessionID),
            serviceType: Self.serviceType
        )
        advertiser.delegate = self

        stateQueue.sync {
            self.session = session
            self.advertiser = advertiser
            self.myCard = card
        }
        advertiser.startAdvertisingPeer()
        startConnectRetryTimer()
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
            connectTimer?.cancel()
            connectTimer = nil
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

            let browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: Self.serviceType)
            browser.delegate = self
            stateQueue.sync { self.browser = browser }
            browser.startBrowsingForPeers()
        }
    }

    // MARK: - Data Transfer

    /// 명함 전체를 보낸다. **사용자가 행을 탭했을 때만** 호출된다.
    ///
    /// 아직 연결되지 않았으면 먼저 초대한다 — 자동 연결은 MPC 동시 세션 한도(8) 안에서만
    /// 이뤄지므로, 한도 밖 피어는 탭하는 시점에 연결한다. 연결을 기다린 뒤 보낸다.
    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        let (session, peerID) = stateQueue.sync { (self.session, peersBySessionID[peer.id]) }
        guard let session, let peerID else {
            throw NearbyError.invalidPayload("발견되지 않은 피어: \(peer.id)")
        }

        let alreadyConnected = session.connectedPeers.contains(peerID)
        log("전송 요청 \(peer.id) — 연결됨: \(alreadyConnected)")
        if !alreadyConnected {
            try await waitForConnection(to: peerID, session: session)
        }
        try sendMessage(.card(payload), to: [peerID], session: session)
        log("명함 전송 완료 \(peer.id)")
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

    // MARK: - Private Function

    /// 기기 하드웨어 식별자 (`iPhone17,3` · `iPad16,1`).
    ///
    /// `UIDevice.name` 을 못 쓰기 때문에 이걸 쓴다 — iOS 16부터 entitlement 없이는 기기
    /// 이름 대신 기종명만 준다. 하드웨어 식별자는 그 제약을 받지 않는다.
    ///
    /// 이걸로는 **같은 기종 두 대를 가르지 못한다.** 그 구분은 세션 식별자가 맡는다.
    /// 여기서 하려는 건 실기기 검증 중 "지금 보는 행이 폰이냐 패드냐" 하나뿐이다.
    public static var hardwareModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: MemoryLayout.size(ofValue: pointer.pointee)
            ) { String(validatingCString: $0) ?? "unknown" }
        }
    }

    /// 이 실행에서 나를 가리키는 식별자. 검증 화면이 "내가 누구인지" 보여줄 때 쓴다.
    public var localPeerDescription: String {
        "\(Self.hardwareModel) · \(localSessionID)"
    }

    /// 발견한 피어의 기기 식별자. DEBUG 광고에만 실리므로 릴리스에서는 항상 `nil`.
    public func deviceModel(forPeerID peerID: String) -> String? {
        stateQueue.sync { deviceModels[peerID] }
    }

    private static func makeSessionID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "")
            .prefix(Constants.sessionIDLength))
            .lowercased()
    }

    /// 명함에서 발견 목록에 필요한 최소 정보만 뽑는다.
    ///
    /// Bonjour TXT 레코드라 크기가 작아 **이메일·외부 링크는 넣지 않는다.** 넣을 자리도 없고,
    /// 동의 전에 흐르는 정보이므로 넣어서도 안 된다.
    static func discoveryInfo(from card: ExchangePayload, sessionID: String) -> [String: String] {
        var info: [String: String] = [
            DiscoveryKey.sessionID: sessionID,
            DiscoveryKey.name: truncated(card.name),
            DiscoveryKey.nickname: truncated(card.nickname),
            DiscoveryKey.part: truncated(card.part),
            DiscoveryKey.generation: truncated(card.generation),
        ]
        if let avatarURL = card.avatarURL, !avatarURL.isEmpty {
            info[DiscoveryKey.avatarURL] = truncated(avatarURL)
        }
        #if DEBUG
        // 검증 전용. 릴리스 광고에는 싣지 않는다 — 기능에 필요 없는 정보를 주변에
        // 뿌릴 이유가 없다.
        info[DiscoveryKey.device] = hardwareModel
        #endif
        return info
    }

    private static func truncated(_ value: String) -> String {
        String(value.prefix(Constants.maxDiscoveryValueLength))
    }

    /// `discoveryInfo` 를 발견 피어로 옮긴다.
    ///
    /// 세션 식별자가 없는 광고는 우리 앱이 만든 게 아니거나 구버전이므로 무시한다 —
    /// 식별자 없이는 피어를 구분할 수 없다.
    private static func makePeer(from info: [String: String]?) -> DiscoveredPeer? {
        guard let info, let sessionID = info[DiscoveryKey.sessionID], !sessionID.isEmpty else {
            return nil
        }
        let name = info[DiscoveryKey.name]
        let nickname = info[DiscoveryKey.nickname]
        let displayName: String? = {
            guard let name else { return nil }
            guard let nickname, !nickname.isEmpty else { return name }
            return "\(name)/\(nickname)"
        }()

        return DiscoveredPeer(
            id: sessionID,
            displayName: displayName,
            part: info[DiscoveryKey.part],
            generation: info[DiscoveryKey.generation],
            avatarURL: info[DiscoveryKey.avatarURL]
        )
    }

    /// 초대를 보내는 **유일한 지점**. `stateQueue` 안에서만 호출한다.
    ///
    /// 경로를 하나로 모은 이유가 핵심이다. 예전에는 발견(`foundPeer`)과 탭(`send`)이 각자
    /// 초대를 보냈는데, 탭 경로는 타이브레이크를 무시했다. 식별자가 큰 쪽에서 탭하면 상대의
    /// 자동 초대와 겹쳐 **같은 쌍에 두 연결 시도가 포개지고 둘 다 실패한다.** 실기기에서
    /// 「첫 탭은 20초 만에 실패, 두 번째 탭은 성공」 으로 나타났던 증상이 이것이다 —
    /// 두 번째 탭 때는 경쟁하는 초대가 이미 죽어 있어서 통했다.
    ///
    /// 세 가지를 모두 통과해야 초대를 보낸다: 아직 연결 안 됨 · 시도 중 아님 · 내가 초대 담당.
    private func inviteIfNeeded(_ peerID: MCPeerID, reason: String) {
        guard let session, let browser else { return }
        let sessionID = peerID.displayName

        guard !session.connectedPeers.contains(peerID) else { return }
        guard !connectingSessionIDs.contains(sessionID) else { return }
        // 식별자가 작은 쪽이 초대를 맡는다. 양쪽이 같은 두 값을 보고 같은 결론에 도달하므로
        // 합의 절차가 필요 없다.
        guard localSessionID < sessionID else { return }

        connectingSessionIDs.insert(sessionID)
        appendLog("초대 \(sessionID) — \(reason)")
        browser.invitePeer(
            peerID, to: session, withContext: nil, timeout: Constants.invitationTimeout
        )
    }

    /// 발견됐지만 연결되지 않은 피어를 다시 초대한다. **`stateQueue` 에서 실행된다.**
    ///
    /// `foundPeer` 는 피어당 한 번만 불린다 — "재발견마다 재시도한다"는 예전 주석은 MPC 의
    /// 실제 동작과 달랐다. 초대가 유실되면 되살릴 경로가 없어 조용히 연결되지 않은 채 남았다.
    private func retryPendingInvitations() {
        for peerID in peersBySessionID.values {
            inviteIfNeeded(peerID, reason: "재시도")
        }
    }

    private func startConnectRetryTimer() {
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(
            deadline: .now() + Constants.connectRetryInterval,
            repeating: Constants.connectRetryInterval
        )
        timer.setEventHandler { [weak self] in
            self?.retryPendingInvitations()   // 이미 stateQueue 위 — sync 금지
        }
        stateQueue.sync {
            connectTimer?.cancel()
            connectTimer = timer
        }
        timer.resume()
    }

    /// 연결될 때까지 기다린다. 이미 연결돼 있으면 즉시 반환.
    ///
    /// **여기서 초대를 보내지 않는다** — `inviteIfNeeded` 를 통해서만 나가고, 내가 초대
    /// 담당이 아니면 상대가 부를 때까지 기다린다. 상대 쪽 재시도 타이머가 그 역할을 한다.
    private func waitForConnection(to peerID: MCPeerID, session: MCSession) async throws {
        stateQueue.sync { inviteIfNeeded(peerID, reason: "탭") }
        log("연결 대기 \(peerID.displayName)")

        // MPC 는 연결 완료를 async 로 알려주지 않는다. 델리게이트가 상태를 바꿀 때까지
        // 짧게 폴링한다 — 타임아웃은 초대 타임아웃과 같은 값을 쓴다.
        let deadline = Date().addingTimeInterval(Constants.invitationTimeout)
        while Date() < deadline {
            if session.connectedPeers.contains(peerID) { return }
            try? await Task.sleep(for: .milliseconds(120))
        }
        throw NearbyError.transportFailure(
            underlying: NearbyError.invalidPayload("연결 시간 초과")
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
        stateQueue.sync {
            _lastTransportError = "[\(stage)] \(error)"
            appendLog("실패 [\(stage)] \(error)")
        }
    }

    /// **`stateQueue` 안에서만 호출한다.**
    private func appendLog(_ line: String) {
        _log.insert(line, at: 0)
        if _log.count > 40 { _log.removeLast(_log.count - 40) }
    }

    private func log(_ line: String) {
        stateQueue.sync { appendLog(line) }
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
            peersBySessionID.removeAll()
            discoveredPeers.removeAll()
            deviceModels.removeAll()
            repliedSessionIDs.removeAll()
            connectingSessionIDs.removeAll()
            pendingPayloads.removeAll()
        }
    }

    /// 광고·탐색·세션만 정리한다. **수신 continuation 은 건드리지 않는다** (위 주석 참고).
    private func tearDownChannels() {
        let (advertiser, browser, session) = stateQueue.sync {
            (self.advertiser, self.browser, self.session)
        }
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        stateQueue.sync {
            connectTimer?.cancel()
            connectTimer = nil
            self.advertiser = nil
            self.browser = nil
            self.session = nil
            self.myCard = nil
        }
        resetSessionState()
    }

    private func tearDown() {
        stateQueue.sync {
            connectTimer?.cancel()
            connectTimer = nil
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
        log("초대 받음 \(peerID.displayName) — \(session == nil ? "거절(세션 없음)" : "수락")")
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
        guard let peer = Self.makePeer(from: info) else { return }
        let deviceModel = info?[DiscoveryKey.device]

        // 발견 즉시 연결을 건다 — NI 토큰을 주고받으려면 세션이 필요하고, 토큰이 없으면
        // 거리를 잴 수 없다. 명함은 여전히 사용자가 탭해야 나간다.
        //
        // 광고보다 탐색이 먼저 서면 이 시점에 세션이 없을 수 있다. 그래도 매핑은 **남긴다** —
        // 재시도 타이머가 세션이 생긴 뒤 초대를 이어받는다. 예전에는 여기서 매핑을 지웠는데,
        // `foundPeer` 가 피어당 한 번만 불려서 그 피어는 영영 초대받지 못했다.
        stateQueue.sync {
            let isNew = peersBySessionID[peer.id] == nil
            peersBySessionID[peer.id] = peerID
            discoveredPeers[peer.id] = peer
            deviceModels[peer.id] = deviceModel
            peerContinuation?.yield(peer)
            if isNew {
                let who = deviceModel.map { "\($0) " } ?? ""
                appendLog(
                    "발견 \(who)\(peer.id)"
                    + (localSessionID < peer.id ? "" : " — 상대가 초대 담당")
                )
            }
            inviteIfNeeded(peerID, reason: "발견")
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let sessionID = peerID.displayName
        let provider = stateQueue.sync { () -> (any NearbyHandshakeProviding)? in
            peersBySessionID[sessionID] = nil
            discoveredPeers[sessionID] = nil
            deviceModels[sessionID] = nil
            repliedSessionIDs.remove(sessionID)
            connectingSessionIDs.remove(sessionID)
            return handshakeProvider
        }
        log("피어 소실 \(sessionID)")
        provider?.didLosePeer(sessionID)
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
        let name: String = {
            switch state {
            case .connected:    return "connected"
            case .connecting:   return "connecting"
            case .notConnected: return "notConnected"
            @unknown default:   return "unknown"
            }
        }()
        // 연결 시도 표식을 여기서 걷는다. `.notConnected` 로 떨어졌는데 표식이 남으면
        // 재시도 타이머가 그 피어를 영영 건너뛴다.
        let sessionIDForState = peerID.displayName
        stateQueue.sync {
            switch state {
            case .connecting:
                connectingSessionIDs.insert(sessionIDForState)
            case .connected, .notConnected:
                connectingSessionIDs.remove(sessionIDForState)
            @unknown default:
                connectingSessionIDs.remove(sessionIDForState)
            }
            appendLog("세션 상태 \(sessionIDForState) → \(name)")
        }

        guard state == .connected else { return }

        // 연결되면 핸드셰이크를 보낸다. 여기 실리는 건 NI 토큰과 미리보기뿐 — 명함이 아니다.
        // 토큰은 피어마다 다르므로 그때그때 만든다 (NearbyHandshakeProviding 주석 참고).
        // 초대를 수락해 연결된 피어는 발견 경로를 안 거쳤을 수 있다. 여기서 매핑을 보강해
        // 두면 이후 `send(payload:to:)` 가 그 피어를 찾지 못하는 일이 없다.
        let sessionID = peerID.displayName
        let provider = stateQueue.sync { () -> (any NearbyHandshakeProviding)? in
            peersBySessionID[sessionID] = peerID
            return handshakeProvider
        }
        guard let provider,
              let handshake = provider.makeHandshake(forPeerID: sessionID) else { return }
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
            guard let provider = stateQueue.sync(execute: { handshakeProvider }) else { return }
            provider.didReceiveHandshake(handshake, fromPeerID: peerID.displayName)

        case .card(let payload):
            let reply = stateQueue.sync { () -> ExchangePayload? in
                let isBuffered = receiveContinuation == nil
                if let continuation = receiveContinuation {
                    continuation.yield(payload)
                } else {
                    pendingPayloads.append(payload)   // 구독 전 도착분
                }
                // 수신 자체를 남긴다. 이 줄이 없어서 「명함이 도착은 했는데 저장이 안 된
                // 것」과 「애초에 도착하지 않은 것」을 구분할 수 없었다.
                // 이름은 남기지 않는다 — 이 버퍼는 릴리스에도 존재한다.
                appendLog(
                    "명함 수신 \(peerID.displayName) — cardID \(payload.cardID.prefix(8))"
                    + (isBuffered ? " (구독 전, 버퍼)" : "")
                )
                // 맞교환은 **연결당 1회**. 빠지면 A→B→A→B 무한 에코가 된다.
                guard repliedSessionIDs.insert(peerID.displayName).inserted else { return nil }
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
