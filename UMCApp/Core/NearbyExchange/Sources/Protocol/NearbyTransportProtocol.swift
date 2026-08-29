//
//  NearbyTransportProtocol.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

// MARK: - DiscoveredPeer

/// 스캔 중 발견된 상대 피어 정보.
///
/// 광고가 실제로 나르는 값만 담는다. 한때 `cardUUIDPrefix`·`version`·`flags` 를 들고
/// 있었는데 BLE 광고 패킷을 전제한 필드였다. transport 가 MPC 로 좁혀지면서 광고는
/// Bonjour TXT 딕셔너리가 됐고 저 셋은 어디에서도 오지 않아 늘 상수였다 — 「광고에서
/// 추출한 값」이라는 선언만 남고 실제로는 로컬 상수였으므로 걷어냈다.
public struct DiscoveredPeer: Sendable, Identifiable, Equatable {

    // MARK: - Property

    /// transport 가 피어를 가르는 키. MPC 에서는 광고에 실린 세션 식별자다.
    public let id: String
    public let discoveredAt: Date
    /// 스캔 UI 표시용 이름. 광고가 이름을 싣지 않는 transport 에서는 nil (무 PII 정책 PRD Q2).
    public let displayName: String?
    /// 표시용 파트 apiValue. 채널이 제공할 때만 채운다.
    public let part: String?
    /// 표시용 기수. 채널이 제공할 때만 채운다.
    public let generation: String?
    /// 표시용 아바타 URL.
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
        discoveredAt: Date = Date(),
        displayName: String? = nil,
        part: String? = nil,
        generation: String? = nil,
        avatarURL: String? = nil,
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.discoveredAt = discoveredAt
        self.displayName = displayName
        self.part = part
        self.generation = generation
        self.avatarURL = avatarURL
        self.distanceMeters = distanceMeters
    }

    /// UWB 실측 거리를 얹은 사본. 레인징이 갱신될 때마다 교체한다.
    public func applying(distanceMeters: Double?) -> DiscoveredPeer {
        DiscoveredPeer(
            id: id,
            discoveredAt: discoveredAt,
            displayName: displayName,
            part: part,
            generation: generation,
            avatarURL: avatarURL,
            distanceMeters: distanceMeters
        )
    }
}

// MARK: - NearbyHandshakeProviding

/// 피어별 핸드셰이크를 만들고 상대 핸드셰이크를 받는 쪽 (레인징 조율 계층).
///
/// **피어마다 달라야 하는 이유**: `NISession` 은 한 번에 한 상대와만 레인징한다
/// (`NINearbyPeerConfiguration(peerToken:)` 이 상대 토큰 하나를 받는다). 그래서 상대가 늘면
/// 세션도 늘고, 세션마다 자기 `discoveryToken` 이 다르다. 전역 토큰 하나를 뿌리면
/// 두 번째 상대부터 엉뚱한 세션의 토큰을 받는다.
public protocol NearbyHandshakeProviding: AnyObject, Sendable {

    /// 이 피어에게 보낼 핸드셰이크. UWB 미탑재 기기는 `niToken` 을 `nil` 로 채운다.
    func makeHandshake(forPeerID peerID: String) -> NearbyHandshake?

    /// 상대 핸드셰이크 도착. 여기서 상대 토큰으로 레인징을 시작한다.
    func didReceiveHandshake(_ handshake: NearbyHandshake, fromPeerID peerID: String)

    /// 피어가 사라졌다. 해당 세션을 정리한다.
    func didLosePeer(_ peerID: String)
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

    // MARK: - Ranging

    /// 레인징 조율 계층을 연결한다. 연결 수립 시점에 ``NearbyHandshake`` 를 주고받는 배선이다.
    ///
    /// **기본 구현을 두지 않는 이유**: NI 토큰은 데이터 채널이 있어야만 건널 수 있어서
    /// (NearbyInteraction 은 스스로 토큰을 나르지 못한다) 이 배선이 없으면 거리가 조용히
    /// 비어버린다. 프로토콜 요구사항으로 두면 새 transport 는 나를지 말지를 반드시 정하게
    /// 된다 — 나르지 않기로 했다면 빈 구현에 그 사유를 적는다.
    func setHandshakeProvider(_ provider: any NearbyHandshakeProviding)
}
