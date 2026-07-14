//
//  UWBTransport.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation
import NearbyInteraction

// MARK: - UWBTransport

/// Phase 2 UWB 전송 구현체 — 스켈레톤.
///
/// iPhone 11+ UWB 칩(U1) 기반 방향 감지 교환을 지원할 예정.
/// NISession을 통해 상대 기기의 방향·거리를 실시간으로 수신하고,
/// "폰을 향하면 자동 교환" 트리거로 활용한다.
///
/// Phase 2 전까지 모든 메서드는 `NearbyError.notImplemented`를 throw 한다.
public final class UWBTransport: NSObject, NearbyTransportProtocol {

    // MARK: - Property

    private var session: NISession?

    // MARK: - Init

    public override init() {
        super.init()
    }

    // MARK: - NearbyTransportProtocol

    public func startAdvertising(payload: BLEAdvertisementPayload) async throws {
        throw NearbyError.notImplemented
    }

    public func stopAdvertising() async {}

    public func startScanning() -> AsyncStream<DiscoveredPeer> {
        AsyncStream { continuation in
            // Phase 2 — not implemented
            continuation.finish()
        }
    }

    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        throw NearbyError.notImplemented
    }

    public func receive() -> AsyncStream<ExchangePayload> {
        AsyncStream { continuation in
            // Phase 2 — not implemented
            continuation.finish()
        }
    }
}

// MARK: - NISessionDelegate

extension UWBTransport: NISessionDelegate {
    public func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // TODO: Phase 2 — 방향/거리 임계값 충족 시 교환 트리거.
        //        ARPairingCoordinator와 연동해 AR 공간에 3D 명함 표시.
    }

    public func session(_ session: NISession, didInvalidateWith error: Error) {
        // TODO: Phase 2 — 세션 복구 로직
    }
}
