//
//  NearbyRangingController.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import Foundation
import NearbyInteraction
import simd

/// `NISession` 래퍼 — 상대와의 거리·방향을 콜백으로 흘린다.
///
/// **NI는 데이터 채널이 아니다.** 명함을 나르지 않고 거리·방향만 준다. 그래서 상대의
/// 디스커버리 토큰을 먼저 다른 경로로 받아야 시작할 수 있다. 스파이크에서는 Wi-Fi Aware
/// 연결로 토큰을 교환했는데, 검증 화면에서는 **QR로 교환**한다 — 페어링·capability 없이도
/// UWB 동작을 볼 수 있기 때문이다.
///
/// - Note: `@unchecked Sendable` — session은 메인에서만 만지고 delegate 콜백은 읽기 전용이다.
final class NearbyRangingController: NSObject, NISessionDelegate, @unchecked Sendable {

    // MARK: - Update

    struct Update: Sendable {
        let distanceMeters: Float?
        let horizontalAngleDegrees: Float?
    }

    // MARK: - Property

    static var isSupported: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    private var session: NISession?
    private let onUpdate: @MainActor @Sendable (Update) -> Void
    private let onEvent: @MainActor @Sendable (String) -> Void

    // MARK: - Init

    init(
        onUpdate: @escaping @MainActor @Sendable (Update) -> Void,
        onEvent: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.onUpdate = onUpdate
        self.onEvent = onEvent
        super.init()
    }

    // MARK: - Function

    /// 내 디스커버리 토큰을 직렬화해 반환한다 (상대에게 전달용). 세션도 이때 만든다.
    func makeTokenData() -> Data? {
        let session = NISession()
        session.delegate = self
        self.session = session

        guard let token = session.discoveryToken else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    /// 상대 토큰을 받아 레인징을 시작한다.
    func startRanging(withPeerTokenData data: Data) {
        guard let session else {
            Task { @MainActor in onEvent("내 토큰을 먼저 만들어야 한다") }
            return
        }
        guard let peerToken = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self, from: data
        ) else {
            Task { @MainActor in onEvent("NI 토큰 역직렬화 실패") }
            return
        }

        session.run(NINearbyPeerConfiguration(peerToken: peerToken))
        Task { @MainActor in onEvent("UWB 레인징 시작") }
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    // MARK: - NISessionDelegate

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }

        // direction은 수평 시야각 안에서만 온다. 수평각(방위)만 도 단위로 요약한다.
        let horizontalAngle: Float? = object.direction.map { direction in
            atan2(direction.x, -direction.z) * 180 / .pi
        }
        let update = Update(
            distanceMeters: object.distance,
            horizontalAngleDegrees: horizontalAngle
        )
        Task { @MainActor in onUpdate(update) }
    }

    func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        Task { @MainActor in onEvent("UWB 상대 이탈: \(String(describing: reason))") }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        Task { @MainActor in onEvent("UWB 세션 종료: \(error.localizedDescription)") }
    }

    func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in onEvent("UWB 재개") }
    }

    func sessionWasSuspended(_ session: NISession) {
        Task { @MainActor in onEvent("UWB 일시중단 (백그라운드 등)") }
    }
}
#endif
