//
//  NearbyTransportProtocol.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

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
    /// 스캔 UI 표시용 이름. Wi-Fi Aware는 페어링 정보로 채우고, BLE는 무 PII 정책(PRD Q2)상 nil.
    public let displayName: String?
    /// 표시용 파트 apiValue. 채널이 제공할 때만 채운다.
    public let part: String?
    /// 표시용 기수. 채널이 제공할 때만 채운다.
    public let generation: String?

    // MARK: - Init

    public init(
        id: String,
        cardUUIDPrefix: Data,
        version: UInt8,
        flags: UInt8,
        discoveredAt: Date = Date(),
        displayName: String? = nil,
        part: String? = nil,
        generation: String? = nil
    ) {
        self.id = id
        self.cardUUIDPrefix = cardUUIDPrefix
        self.version = version
        self.flags = flags
        self.discoveredAt = discoveredAt
        self.displayName = displayName
        self.part = part
        self.generation = generation
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
    ///
    /// 광고 포맷 변환(BLE 축약 광고 파생·Wi-Fi Aware 서비스 퍼블리시)은 각 transport
    /// 내부 책임이다. 5분 타이머, 화면 이탈 시 `stopAdvertising()` 호출 책임은 호출자에게 있음.
    func startAdvertising(card: ExchangePayload) async throws

    /// 광고 중지. 세션 정리 지점이기도 하다 — 수신 스트림을 여는 transport는
    /// 여기서 스트림을 닫아 소비자가 영구 대기하지 않게 한다.
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
