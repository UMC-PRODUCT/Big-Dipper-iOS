//
//  WiFiAwareTransport.swift
//  CoreNearbyExchange
//
//  Created by One on 8/16/26.
//

import Foundation
import Network
#if canImport(WiFiAware)
import WiFiAware

/// iOS 26 Wi-Fi Aware 기반 근거리 명함 교환 transport.
///
/// 2026-08-15 실기기 스파이크로 검증한 구성을 따른다:
/// - **TCP 프레이밍** (UDP는 1회성 전송 유실)
/// - 링크는 단명 취급 — 교환 성공 후의 idle/광고 타임아웃은 정상 수순이라 에러로 올리지 않는다
/// - 수신 페이로드가 연결 상태 이벤트보다 먼저 흐를 수 있다 (구독 전 도착분은 버퍼링)
/// - 종료 시 모든 continuation을 finish (continuation leak 방지)
///
/// 페어링(DeviceDiscoveryUI)은 Presentation 몫. 미페어링 상태의 시작은
/// `NearbyError.notPaired`로 표면화한다.
///
/// **동시성 규칙 (위반하면 데드락·에코 루프)**
/// - `continuation.finish()`는 절대 `stateQueue` 안에서 호출하지 않는다. `onTermination`이
///   finish 호출 스레드에서 동기 실행되므로 직렬 큐 재진입 = 확정 데드락.
/// - `onTermination` 핸들러 본문은 `stateQueue.sync`가 아니라 `.async`.
/// - 맞교환 회신은 **인바운드 연결 + 연결당 1회**. 양쪽이 동시에 광고+스캔하는 세션
///   모델이라 조건이 하나라도 빠지면 무한 에코가 된다.
/// - DI 캐싱으로 이 인스턴스는 앱 수명 싱글톤이다. 세션 상태는 start/stop 진입점에서
///   `resetSessionState()`로 비운다.
public final class WiFiAwareTransport: NearbyTransportProtocol, @unchecked Sendable {

    // MARK: - Constants

    /// Info.plist `WiFiAwareServices` 선언과 일치해야 한다.
    /// 페어링 UI가 같은 서비스를 지목해야 해서 모듈 밖에 노출한다.
    public static let serviceName = "_umc-card._udp"

    private typealias CardConnection =
        NetworkConnection<Coder<ExchangePayload, ExchangePayload, WiFiAwareJSONCoder>>

    // MARK: - Property

    public static var isSupported: Bool {
        WACapabilities.supportedFeatures.contains(.wifiAware)
    }

    private let stateQueue = DispatchQueue(label: "dev.umc.nearby.wifiaware")
    private var listenerTask: Task<Void, Never>?
    private var browserTask: Task<Void, Never>?
    private var connections: [String: CardConnection] = [:]
    private var endpointsByPeerID: [String: WAEndpoint] = [:]
    private var myCardPayload: ExchangePayload?
    /// 첫 페이로드 수신 여부 — 이후의 링크 실패는 정상 수순으로 취급 (스파이크 ②).
    /// **세션 스코프**다 — 리셋하지 않으면 두 번째 세션의 교환 전 실패까지 침묵된다.
    private var hasExchanged = false
    /// 맞교환 회신을 이미 보낸 연결 — 연결당 1회만 회신해 무한 에코를 막는다.
    private var repliedConnectionIDs = Set<String>()
    /// receive() 구독 전에 도착한 페이로드. 구독 시점에 흘려보낸다 (스파이크 ③).
    private var pendingPayloads: [ExchangePayload] = []

    private var peerContinuation: AsyncStream<DiscoveredPeer>.Continuation?
    private var receiveContinuation: AsyncStream<ExchangePayload>.Continuation?

    // MARK: - Init

    public init() {}

    deinit {
        tearDownAll()
    }

    // MARK: - Advertising (Publisher)

    public func startAdvertising(card: ExchangePayload) async throws {
        guard Self.isSupported else {
            throw NearbyError.unsupported("Wi-Fi Aware")
        }
        guard try await hasPairedDevices() else {
            throw NearbyError.notPaired
        }
        // DI 캐싱으로 이 인스턴스는 앱 수명 싱글톤이다 — 새 세션 진입마다 상태를 비운다.
        resetSessionState()
        stateQueue.sync { myCardPayload = card }

        let listenerWork = Task { [weak self] in
            do {
                try await NetworkListener(
                    for: .wifiAware(
                        .connecting(to: .umcCardPublishable, from: .allPairedDevices)
                    ),
                    using: .parameters {
                        Coder(
                            receiving: ExchangePayload.self,
                            sending: ExchangePayload.self,
                            using: WiFiAwareJSONCoder()
                        ) {
                            TCP()   // 스파이크 ①: UDP 유실 → TCP 필수
                        }
                    }
                )
                // 중첩 클로저는 캡처 리스트를 따로 둔다 — 바깥 Task의 weak 변수를 그대로
                // 참조하면 동시 실행 컨텍스트에서 var 캡처 경고(Swift 6에선 에러)가 난다.
                .run { [weak self] connection in
                    // listener가 수락한 인바운드 연결 — 이쪽만 맞교환 회신 책임을 진다.
                    await self?.attach(connection, isInbound: true)
                }
            } catch {
                // 광고 타임아웃(-11989) 등 — 교환 후라면 정상 수순 (스파이크 ②)
                self?.handleLinkEnd(error)
            }
        }
        stateQueue.sync { listenerTask = listenerWork }
    }

    /// 이 transport에서는 **세션 종료 지점**이다 — 광고 중지에 더해 수신 스트림을 닫고
    /// 세션 상태를 비운다. UseCase의 `stop()`이 호출하는 유일한 transport API라
    /// 여기서 정리하지 않으면 receive 스트림 소비자가 영구 대기한다 (스파이크 ④).
    public func stopAdvertising() async {
        stateQueue.sync {
            listenerTask?.cancel()
            listenerTask = nil
            myCardPayload = nil
        }
        // finish는 반드시 락 밖 — onTermination이 같은 직렬 큐에 재진입하면 데드락.
        takeReceiveContinuation()?.finish()
        resetSessionState()
    }

    // MARK: - Scanning (Subscriber)

    public func startScanning() -> AsyncStream<DiscoveredPeer> {
        resetSessionState()

        return AsyncStream { continuation in
            stateQueue.sync { peerContinuation = continuation }
            continuation.onTermination = { [weak self] _ in
                // sync 금지 — 이 핸들러는 finish()를 호출한 스레드에서 동기 실행된다.
                self?.stateQueue.async {
                    self?.browserTask?.cancel()
                    self?.browserTask = nil
                    self?.peerContinuation = nil
                }
            }

            guard Self.isSupported else {
                continuation.finish()
                return
            }

            let browserWork = Task { [weak self] in
                do {
                    let browser = NetworkBrowser(
                        for: .wifiAware(
                            .connecting(to: .allPairedDevices, from: .umcCardSubscribable)
                        )
                    )
                    // Void 오버로드를 쓴다 — RunResult를 반환하는 제네릭 오버로드는
                    // `.finish(_:)` 없이 `.continue`만 돌려주면 Return 타입 추론이 실패한다.
                    // 세션 내내 발견 스트림을 흘려야 하므로 종료 값 자체가 없다.
                    try await browser.run { [weak self] endpoints in
                        self?.publish(endpoints: endpoints)
                    }
                } catch {
                    // 취소·타임아웃 — 스트림만 닫는다 (스파이크 ④: leak 없이 finish)
                }
                self?.takePeerContinuation()?.finish()
            }
            stateQueue.sync { browserTask = browserWork }
        }
    }

    // MARK: - Data Transfer

    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        let endpoint = stateQueue.sync { endpointsByPeerID[peer.id] }
        guard let endpoint else {
            throw NearbyError.invalidPayload("발견되지 않은 피어: \(peer.id)")
        }

        let connection = CardConnection(
            to: endpoint,
            using: .parameters {
                Coder(
                    receiving: ExchangePayload.self,
                    sending: ExchangePayload.self,
                    using: WiFiAwareJSONCoder()
                ) {
                    TCP()
                }
            }
        )
        // 아웃바운드 연결 — 내가 먼저 보내는 쪽이라 회신 책임이 없다(에코 루프 차단).
        await attach(connection, isInbound: false)
        do {
            try await connection.send(payload)
        } catch {
            throw NearbyError.transportFailure(underlying: error)
        }
    }

    public func receive() -> AsyncStream<ExchangePayload> {
        AsyncStream { continuation in
            // 구독 전에 도착한 페이로드를 먼저 흘린다 — 광고/구독 순서에 의존하지 않는다.
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

    /// 연결을 수명 관리에 편입하고 수신 루프를 건다.
    ///
    /// **맞교환 프로토콜 규약**: 인바운드(listener가 수락한) 연결에서만, 그리고
    /// 연결당 **최초 1회만** 내 명함을 같은 연결로 회신한다. 인바운드 피어는
    /// `DiscoveredPeer`로 노출되지 않아 UseCase가 `send`로 응답할 수 없기 때문에
    /// 맞교환은 transport 계층 응답이다.
    ///
    /// 조건이 둘 다 필요한 이유: 세션 모델상 **양쪽 기기가 동시에 광고+스캔**하므로
    /// 아웃바운드까지 회신하면 A→B→A→B… 무한 에코가 된다. 무한 왕복은 트래픽을
    /// 계속 흘려 스파이크 ②의 idle(-11986) 정상 종료도 오지 않게 만든다.
    private func attach(_ connection: CardConnection, isInbound: Bool) async {
        stateQueue.sync { connections[connection.id] = connection }

        Task { [weak self] in
            do {
                for try await (payload, _) in connection.messages {
                    guard let self else { return }

                    let myCard = self.stateQueue.sync { () -> ExchangePayload? in
                        self.hasExchanged = true
                        if let continuation = self.receiveContinuation {
                            continuation.yield(payload)
                        } else {
                            self.pendingPayloads.append(payload)   // 구독 전 도착분
                        }
                        guard isInbound,
                              self.repliedConnectionIDs.insert(connection.id).inserted else {
                            return nil
                        }
                        return self.myCardPayload
                    }

                    if let myCard {
                        try? await connection.send(myCard)
                    }
                }
            } catch {
                self?.handleLinkEnd(error)
            }
            self?.stateQueue.sync {
                self?.connections[connection.id] = nil
                self?.repliedConnectionIDs.remove(connection.id)
            }
        }
    }

    private func publish(endpoints: [WAEndpoint]) {
        stateQueue.sync {
            for endpoint in endpoints {
                let device = endpoint.device
                let peerID = String(describing: device.id)
                guard endpointsByPeerID[peerID] == nil else { continue }
                endpointsByPeerID[peerID] = endpoint

                let peer = DiscoveredPeer(
                    id: peerID,
                    cardUUIDPrefix: Data(),
                    version: UInt8(clamping: ExchangePayload.currentVersion),
                    flags: 0,
                    displayName: device.name ?? device.pairingInfo?.pairingName
                )
                peerContinuation?.yield(peer)
            }
        }
    }

    /// 링크 종료 처리 — 교환 성공 후라면 정상 수순이라 침묵, 이전이라면 스트림 종료로 표면화.
    ///
    /// 스파이크 ②가 "반드시 온다"고 한 경로(-11989 publisherTimeout: 아무도 접속 안 한
    /// 광고 만료)를 그대로 지나므로, 여기서 락을 잡은 채 finish하면 교환 실패 세션마다
    /// 스레드가 영구 블록된다. 반드시 continuation을 꺼낸 뒤 **락 밖에서** finish한다.
    private func handleLinkEnd(_ error: Error) {
        let exchanged = stateQueue.sync { hasExchanged }
        guard !exchanged else { return }
        takeReceiveContinuation()?.finish()
    }

    private func hasPairedDevices() async throws -> Bool {
        for try await devices in WAPairedDevice.allDevices {
            return !devices.isEmpty
        }
        return false
    }

    // MARK: - Continuation Handoff

    /// 락 안에서 꺼내고 **락 밖에서** finish하기 위한 인출 헬퍼.
    /// `onTermination`은 finish를 부른 스레드에서 동기 실행되므로, 락을 잡은 채
    /// finish하면 같은 직렬 큐에 재진입해 확정 데드락이 난다.
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

    /// 새 세션 진입점(startAdvertising·startScanning·stopAdvertising)에서 호출한다.
    /// DI가 인스턴스를 캐싱해 이 transport는 앱 수명 싱글톤이라, 리셋하지 않으면
    /// ① 이미 발견한 기기가 다음 세션에서 peerFound로 다시 나오지 않고
    /// ② `hasExchanged`가 true로 굳어 이후 모든 세션의 실패가 침묵된다.
    private func resetSessionState() {
        stateQueue.sync {
            hasExchanged = false
            endpointsByPeerID.removeAll()
            repliedConnectionIDs.removeAll()
            pendingPayloads.removeAll()
            connections.removeAll()
        }
    }

    private func tearDownAll() {
        stateQueue.sync {
            listenerTask?.cancel()
            browserTask?.cancel()
            connections.removeAll()
            endpointsByPeerID.removeAll()
        }
        takePeerContinuation()?.finish()
        takeReceiveContinuation()?.finish()
    }
}

// MARK: - Service Extensions

// public인 이유: 페어링 UI(DeviceDiscoveryUI)가 같은 서비스를 지목해야 하는데,
// 그 UI는 Presentation/App 레이어 몫이라 모듈 밖에서 이 값을 참조한다.
// Info.plist `WiFiAwareServices` 선언과 이름이 반드시 같아야 한다.
public extension WAPublishableService {
    static var umcCardPublishable: WAPublishableService {
        allServices[WiFiAwareTransport.serviceName]!
    }
}

public extension WASubscribableService {
    static var umcCardSubscribable: WASubscribableService {
        allServices[WiFiAwareTransport.serviceName]!
    }
}

// MARK: - Coder

/// ExchangePayload JSON 프레이밍 (ISO8601 — `ExchangePayload.jsonData()`와 동일 전략).
///
/// SDK에 같은 자리의 `Network.NetworkJSONCoder`가 있고 스파이크 토이는 그걸 그대로 썼지만,
/// 기본 JSONEncoder는 날짜를 `.deferredToDate`(숫자)로 직렬화한다. QR 경로가 `.iso8601`
/// 이므로 채널마다 timestamp 표현이 갈리면 Android와 공유하는 스키마가 한 벌로 성립하지
/// 않는다 — 전략만 바꿔 직접 채택한다.
///
/// (`NWProtocolFramerMessageCoder`라는 타입은 SDK에 없다. iPhoneOS26.5 SDK의
/// Network.swiftinterface 확인: 채택할 프로토콜은 `NetworkCoder` —
/// `init()` + `makeEncoder()` + `makeDecoder()` 3요구사항이 전부다.)
struct WiFiAwareJSONCoder: NetworkCoder {

    func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
#else
/// WiFiAware 미지원 SDK 폴백 — 컴파일만 통과시키고 런타임엔 unsupported를 던진다.
public final class WiFiAwareTransport: NearbyTransportProtocol, @unchecked Sendable {
    public static var isSupported: Bool { false }
    public init() {}
    public func startAdvertising(card: ExchangePayload) async throws {
        throw NearbyError.unsupported("Wi-Fi Aware")
    }
    public func stopAdvertising() async {}
    public func startScanning() -> AsyncStream<DiscoveredPeer> {
        AsyncStream { $0.finish() }
    }
    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        throw NearbyError.unsupported("Wi-Fi Aware")
    }
    public func receive() -> AsyncStream<ExchangePayload> {
        AsyncStream { $0.finish() }
    }
}
#endif
