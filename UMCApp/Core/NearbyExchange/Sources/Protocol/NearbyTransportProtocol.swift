import Foundation

// MARK: - DiscoveredPeer

/// 스캔 중 발견된 상대 피어 정보.
/// BLE 광고 페이로드에서 추출한 최소 식별 정보만 포함 (PII 미포함 — PRD Q2 결정).
public struct DiscoveredPeer: Sendable, Identifiable, Equatable {

    // MARK: - Property

    /// BLE 광고에서 수신한 cardUUID prefix (8 bytes)
    public let id: String
    public let cardUUIDPrefix: Data
    public let version: UInt8
    public let flags: UInt8
    public let discoveredAt: Date

    // MARK: - Init

    public init(id: String, cardUUIDPrefix: Data, version: UInt8, flags: UInt8, discoveredAt: Date = Date()) {
        self.id = id
        self.cardUUIDPrefix = cardUUIDPrefix
        self.version = version
        self.flags = flags
        self.discoveredAt = discoveredAt
    }
}

// MARK: - NearbyTransportProtocol

/// 근거리 명함 교환 전송 레이어 추상화.
///
/// BusinessCard 피처는 이 프로토콜에만 의존한다. 구체 전송 구현(BLE, NFC, UWB)은
/// DIContainer에서 주입받으며 피처 레이어는 교체를 인지하지 않는다.
///
/// - Phase 1: BLETransport / NFCTransport 구현 제공
/// - Phase 2: UWBTransport + ARPairingCoordinator로 교체 예정
public protocol NearbyTransportProtocol: Sendable {

    // MARK: - Advertising

    /// 명함 교환 광고 시작. PRD Q4 결정: "교환 시작" 버튼 탭 시 호출.
    /// 5분 타이머, 화면 이탈 시 `stopAdvertising()` 호출 책임은 호출자에게 있음.
    func startAdvertising(payload: BLEAdvertisementPayload) async throws

    func stopAdvertising() async

    // MARK: - Scanning

    /// 주변 피어를 지속 스캔. 화면이 살아있는 동안 구독 유지.
    func startScanning() -> AsyncStream<DiscoveredPeer>

    // MARK: - Data Transfer

    /// 발견된 피어에게 전체 명함 페이로드 전송 (GATT 또는 NFC 채널).
    func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws

    /// 상대로부터 수신된 명함 페이로드 스트림.
    func receive() -> AsyncStream<ExchangePayload>
}
