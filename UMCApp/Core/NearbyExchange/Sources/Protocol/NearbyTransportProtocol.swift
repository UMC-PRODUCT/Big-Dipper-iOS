//
//  NearbyTransportProtocol.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

// MARK: - DiscoveredPeer

/// 스캔 중 발견된 상대 피어 정보.
/// 광고에서 추출한 최소 식별 정보만 포함 (PII 미포함 — PRD Q2 결정).
public struct DiscoveredPeer: Sendable, Identifiable, Equatable {

    // MARK: - Property

    /// 광고에서 수신한 cardUUID prefix (8 bytes)
    public let id: String
    public let cardUUIDPrefix: Data
    public let version: UInt8
    public let flags: UInt8
    public let discoveredAt: Date
    /// 스캔 UI 표시용 이름. 핸드셰이크(PeerPreview)로 받기 전에는 무 PII 정책(PRD Q2)상 nil.
    public let displayName: String?
    /// 표시용 파트 apiValue. 채널이 제공할 때만 채운다.
    public let part: String?
    /// 표시용 기수. 채널이 제공할 때만 채운다.
    public let generation: String?
    /// 표시용 아바타 URL. 핸드셰이크로 받은 값.
    public let avatarURL: String?
    /// UWB 실측 거리(미터).
    ///
    /// **transport(MPC) 는 이 값을 주지 못한다** — 거리 API 가 없다. NearbyInteraction 이
    /// 채우며, UWB 미탑재 기기나 측정 전에는 `nil` 이다.
    /// 시안(12654:32621)의 「2.1m」과 신호 막대가 모두 이 값에서 파생된다.
    public let distanceMeters: Double?

    // MARK: - Init

    public init(
        id: String,
        cardUUIDPrefix: Data,
        version: UInt8,
        flags: UInt8,
        discoveredAt: Date = Date(),
        displayName: String? = nil,
        part: String? = nil,
        generation: String? = nil,
        avatarURL: String? = nil,
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.cardUUIDPrefix = cardUUIDPrefix
        self.version = version
        self.flags = flags
        self.discoveredAt = discoveredAt
        self.displayName = displayName
        self.part = part
        self.generation = generation
        self.avatarURL = avatarURL
        self.distanceMeters = distanceMeters
    }

    /// 핸드셰이크로 받은 미리보기를 얹은 사본. 발견은 됐지만 아직 누군지 모르는 행을 채운다.
    public func applying(_ preview: PeerPreview) -> DiscoveredPeer {
        DiscoveredPeer(
            id: id,
            cardUUIDPrefix: cardUUIDPrefix,
            version: version,
            flags: flags,
            discoveredAt: discoveredAt,
            displayName: "\(preview.name)/\(preview.nickname)",
            part: preview.part,
            generation: preview.generation,
            avatarURL: preview.avatarURL,
            distanceMeters: distanceMeters
        )
    }

    /// UWB 실측 거리를 얹은 사본. 레인징이 갱신될 때마다 교체한다.
    public func applying(distanceMeters: Double?) -> DiscoveredPeer {
        DiscoveredPeer(
            id: id,
            cardUUIDPrefix: cardUUIDPrefix,
            version: version,
            flags: flags,
            discoveredAt: discoveredAt,
            displayName: displayName,
            part: part,
            generation: generation,
            avatarURL: avatarURL,
            distanceMeters: distanceMeters
        )
    }
}

// MARK: - NearbyTransportProtocol

/// 근거리 명함 교환 전송 레이어 추상화.
///
/// BusinessCard 피처는 이 프로토콜에만 의존한다. 구체 전송 구현은 DIContainer에서
/// 주입받으며 피처 레이어는 교체를 인지하지 않는다.
///
/// 구현체는 MPCTransport(제품, 2026-08-17 확정)와 MockNearbyTransport(시뮬레이터) 둘이다.
/// BLE·NFC·UWB·Wi-Fi Aware transport 는 검토 끝에 폐기했다 — Wi-Fi Aware 는 사전
/// 페어링된 기기끼리만 연결돼 "처음 만난 사람" 전제가 깨진다. 거리는 NI 가 따로 잰다
/// (PeerRangingCoordinator).
public protocol NearbyTransportProtocol: Sendable {

    // MARK: - Advertising

    /// 명함 교환 광고 시작. PRD Q4 결정: "교환 시작" 버튼 탭 시 호출.
    ///
    /// 광고 포맷 변환은 각 transport 내부 책임이다. 5분 타이머, 화면 이탈 시
    /// `stopAdvertising()` 호출 책임은 호출자에게 있음.
    func startAdvertising(card: ExchangePayload) async throws

    /// 광고 중지. 세션 정리 지점이기도 하다 — 수신 스트림을 여는 transport는
    /// 여기서 스트림을 닫아 소비자가 영구 대기하지 않게 한다.
    func stopAdvertising() async

    // MARK: - Scanning

    /// 주변 피어를 지속 스캔. 화면이 살아있는 동안 구독 유지.
    ///
    /// 발견뿐 아니라 **소실**도 같은 채널로 흐른다 — 목록에서 행을 지우려면 소실 신호가
    /// 제품 화면까지 닿아야 한다 (``NearbyDiscoveryEvent`` 주석 참고).
    func startScanning() -> AsyncStream<NearbyDiscoveryEvent>

    // MARK: - Data Transfer

    /// 발견된 피어에게 전체 명함 페이로드 전송.
    func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws

    /// 상대로부터 수신된 명함 페이로드 스트림.
    func receive() -> AsyncStream<ExchangePayload>
}
