//
//  MockNearbyTransport.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

// MARK: - MockNearbyTransport

/// 테스트/SwiftUI 프리뷰용 NearbyTransport 목(Mock) 구현체.
///
/// 실제 BLE/NFC 하드웨어 없이 교환 흐름 전체를 시뮬레이션할 수 있다.
/// DIContainer에서 Mock Repository로 교체하는 것과 동일한 패턴으로 주입.
public final class MockNearbyTransport: NearbyTransportProtocol {

    // MARK: - Property

    public var stubbedPeers: [DiscoveredPeer]
    public var stubbedPayloads: [ExchangePayload]
    public private(set) var didStartAdvertising = false
    public private(set) var didStopAdvertising = false
    public private(set) var sentPayloads: [ExchangePayload] = []

    // MARK: - Init

    public init(
        stubbedPeers: [DiscoveredPeer] = [],
        stubbedPayloads: [ExchangePayload] = []
    ) {
        self.stubbedPeers = stubbedPeers
        self.stubbedPayloads = stubbedPayloads
    }

    // MARK: - NearbyTransportProtocol

    public func startAdvertising(payload: BLEAdvertisementPayload) async throws {
        didStartAdvertising = true
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
