//
//  MockNearbyTransport.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

#if DEBUG

// MARK: - MockNearbyTransport

/// 테스트/SwiftUI 프리뷰용 NearbyTransport 목(Mock) 구현체.
///
/// 실제 무선 하드웨어 없이 교환 흐름 전체를 시뮬레이션할 수 있다.
/// DIContainer에서 Mock Repository로 교체하는 것과 동일한 패턴으로 주입.
/// 릴리스 빌드에는 포함하지 않는다 (절대 규칙 #5).
public final class MockNearbyTransport: NearbyTransportProtocol {

    // MARK: - Property

    public let stubbedPeers: [DiscoveredPeer]
    public let stubbedPayloads: [ExchangePayload]
    /// 발견 이후에 흘릴 이벤트 — 소실·실패 전파를 테스트에서 그대로 재현한다.
    public let stubbedDiscoveryEvents: [NearbyDiscoveryEvent]
    /// 앞에서 몇 번의 전송을 실패시킬지. 재시도 동작을 재현한다.
    public let sendFailures: Int
    public let sendFailureError: NearbyError
    // 기록용 상태. 목이 Sendable 이라 mutable 저장 프로퍼티는 컴파일러가 막는다.
    // 테스트·프리뷰에서만 단일 스레드로 쓰므로 검사만 끈다.
    public nonisolated(unsafe) private(set) var didStartAdvertising = false
    public nonisolated(unsafe) private(set) var didStopAdvertising = false
    public nonisolated(unsafe) private(set) var sentPayloads: [ExchangePayload] = []
    /// 광고에 실린 명함 기록 — 광고 API 일반화 이후 무엇을 퍼블리시했는지 검증한다.
    public nonisolated(unsafe) private(set) var advertisedCards: [ExchangePayload] = []
    /// 성공·실패를 합친 전송 시도 횟수.
    public nonisolated(unsafe) private(set) var sendAttempts = 0

    // MARK: - Init

    public init(
        stubbedPeers: [DiscoveredPeer] = [],
        stubbedPayloads: [ExchangePayload] = [],
        stubbedDiscoveryEvents: [NearbyDiscoveryEvent] = [],
        sendFailures: Int = 0,
        sendFailureError: NearbyError = .transportFailure(
            underlying: NSError(domain: "MockNearbyTransport", code: 1)
        )
    ) {
        self.stubbedPeers = stubbedPeers
        self.stubbedPayloads = stubbedPayloads
        self.stubbedDiscoveryEvents = stubbedDiscoveryEvents
        self.sendFailures = sendFailures
        self.sendFailureError = sendFailureError
    }

    // MARK: - NearbyTransportProtocol

    public func startAdvertising(card: ExchangePayload) async throws {
        didStartAdvertising = true
        advertisedCards.append(card)
    }

    public func stopAdvertising() async {
        didStopAdvertising = true
    }

    public func startScanning() -> AsyncStream<NearbyDiscoveryEvent> {
        let events = stubbedPeers.map { NearbyDiscoveryEvent.found($0) } + stubbedDiscoveryEvents
        return AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        sendAttempts += 1
        if sendAttempts <= sendFailures { throw sendFailureError }
        sentPayloads.append(payload)
    }

    public func receive() -> AsyncStream<ExchangePayload> {
        let payloads = stubbedPayloads
        return AsyncStream { continuation in
            for payload in payloads {
                continuation.yield(payload)
            }
            continuation.finish()
        }
    }

    /// 의도적으로 아무것도 하지 않는다. Mock 은 실제 무선이 없어 NI 토큰을 건널
    /// 채널이 없고, 레인징 자체가 시뮬레이터에서 동작하지 않는다. 거리가 필요하면
    /// `stubbedPeers` 의 `distanceMeters` 에 직접 넣는다.
    public func setHandshakeProvider(_ provider: any NearbyHandshakeProviding) {}
}

#endif
