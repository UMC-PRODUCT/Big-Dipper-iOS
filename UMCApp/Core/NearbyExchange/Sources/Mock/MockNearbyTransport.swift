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

    public var stubbedPeers: [DiscoveredPeer]
    public var stubbedPayloads: [ExchangePayload]
    public private(set) var didStartAdvertising = false
    public private(set) var didStopAdvertising = false
    public private(set) var sentPayloads: [ExchangePayload] = []
    /// 광고에 실린 명함 기록 — 광고 API 일반화 이후 무엇을 퍼블리시했는지 검증한다.
    public private(set) var advertisedCards: [ExchangePayload] = []

    // MARK: - Init

    public init(
        stubbedPeers: [DiscoveredPeer] = [],
        stubbedPayloads: [ExchangePayload] = []
    ) {
        self.stubbedPeers = stubbedPeers
        self.stubbedPayloads = stubbedPayloads
    }

    // MARK: - NearbyTransportProtocol

    public func startAdvertising(card: ExchangePayload) async throws {
        didStartAdvertising = true
        advertisedCards.append(card)
    }

    public func stopAdvertising() async {
        didStopAdvertising = true
    }

    public func startScanning() -> AsyncStream<DiscoveredPeer> {
        let peers = stubbedPeers
        return AsyncStream { continuation in
            for peer in peers {
                continuation.yield(peer)
            }
            continuation.finish()
        }
    }

    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
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
}

#endif
