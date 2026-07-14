//
//  ARPairingCoordinator.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation
import ARKit
import RealityKit

// MARK: - ARPairingCoordinator

/// Phase 2 AR 모드 스켈레톤.
///
/// UWBTransport로부터 상대 기기 방향/거리 이벤트를 수신하고,
/// ARView 위에 상대방의 3D 명함(USDZ)을 정위치에 앵커링하는 역할.
///
/// Phase 2 전까지 모든 기능은 스텁이다.
/// ARView 생성 및 세션 연결은 BusinessCardPresentation에서 담당하며,
/// 이 Coordinator는 페이로드 → 공간 배치 변환 로직만 책임진다.
public final class ARPairingCoordinator {

    // MARK: - Property

    // Phase 2 — ARView 약한 참조 및 앵커 관리 프로퍼티 예정

    // MARK: - Init

    public init() {}

    // MARK: - Function

    /// 상대방 명함 페이로드를 AR 공간에 배치.
    /// Phase 2 — not implemented.
    public func placeCard(_ payload: ExchangePayload, direction: simd_float3) async throws {
        throw NearbyError.notImplemented
    }

    /// AR 세션 정리.
    public func tearDown() {
        // Phase 2 — ARSession.pause() 호출 예정
    }
}
