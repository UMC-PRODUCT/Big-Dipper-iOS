//
//  NearbyRangingController.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CryptoKit
import Foundation
import NearbyInteraction
import simd

/// `NISession` 래퍼 — 상대와의 거리·방향을 콜백으로 흘린다.
///
/// **NI는 데이터 채널이 아니다.** 명함을 나르지 않고 거리·방향만 준다. 그래서 상대의
/// 디스커버리 토큰을 먼저 다른 경로로 받아야 시작할 수 있다. 스파이크에서는 Wi-Fi Aware
/// (현재는 폐기) 연결로 토큰을 교환했는데, 검증 화면에서는 **QR로 교환**한다 —
/// 페어링·capability 없이도 UWB 동작을 볼 수 있기 때문이다.
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

    /// 내 토큰·상대 토큰의 지문. **두 기기가 서로의 것을 제대로 바꿨는지 확인하는 유일한 수단**이다.
    /// 자기 QR 을 자기가 찍어도 화면상으로는 구분되지 않아서, 이 값이 없으면 「조용히 안 됨」의
    /// 원인을 가릴 수 없다. A 의 내 토큰 지문 == B 의 상대 토큰 지문이어야 정상이다.
    private(set) var myTokenFingerprint: String?
    private(set) var peerTokenFingerprint: String?

    /// 첫 갱신에서만 상세를 남긴다. 갱신은 초당 여러 번 와서 매번 찍으면 로그가 쓸려나간다.
    private var hasLoggedFirstUpdate = false

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

        guard let token = session.discoveryToken else {
            emit("discoveryToken 이 nil — UWB 미지원이거나 세션 생성 실패")
            return nil
        }
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: token, requiringSecureCoding: true
        ) else {
            emit("토큰 직렬화 실패")
            return nil
        }

        myTokenFingerprint = Self.fingerprint(of: data)
        emit("내 토큰 준비 (\(data.count)B, 지문 \(myTokenFingerprint ?? "?"))")
        return data
    }

    /// 상대 토큰을 받아 레인징을 시작한다.
    ///
    /// - Returns: 실제로 `run` 을 호출했는지. 호출부가 「실행 중」 표시를 이 값으로 정한다 —
    ///   시작하지 못했는데 실행 중으로 보이면 계기가 거짓말을 한다.
    @discardableResult
    func startRanging(withPeerTokenData data: Data) -> Bool {
        guard let session else {
            emit("내 토큰을 먼저 만들어야 한다")
            return false
        }
        guard let peerToken = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self, from: data
        ) else {
            emit("NI 토큰 역직렬화 실패 (\(data.count)B)")
            return false
        }

        let scanned = Self.fingerprint(of: data)
        peerTokenFingerprint = scanned

        // 자기 QR 을 자기가 찍는 실수. NI 는 이걸 에러로 알려주지 않고 그냥 조용하다.
        if scanned == myTokenFingerprint {
            emit("⚠️ 내 토큰을 스캔했다 — 상대 폰 화면을 찍어야 한다")
            return false
        }

        hasLoggedFirstUpdate = false
        session.run(NINearbyPeerConfiguration(peerToken: peerToken))
        emit("레인징 시작 (상대 지문 \(scanned))")
        return true
    }

    func stop() {
        session?.invalidate()
        session = nil
        myTokenFingerprint = nil
        peerTokenFingerprint = nil
    }

    // MARK: - NISessionDelegate

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else {
            // 델리게이트는 오는데 대상이 비었다 — 「갱신 0회」와 전혀 다른 상태다.
            emit("갱신은 오는데 nearbyObjects 가 비었다")
            return
        }

        // direction은 수평 시야각 안에서만 온다. 수평각(방위)만 도 단위로 요약한다.
        let horizontalAngle: Float? = object.direction.map { direction in
            atan2(direction.x, -direction.z) * 180 / .pi
        }

        // 첫 갱신에서 무엇이 비어 있는지 남긴다. distance 만 nil 이면 세션은 붙은 것이고,
        // 원인은 거리(너무 가깝다·가려졌다)지 페어링이 아니다.
        if !hasLoggedFirstUpdate {
            hasLoggedFirstUpdate = true
            let distanceState = object.distance == nil ? "nil" : "값 있음"
            let directionState = object.direction == nil ? "nil(시야 밖)" : "값 있음"
            emit("첫 갱신 — distance \(distanceState) · direction \(directionState)")
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
        emit("상대 이탈: \(String(describing: reason))")
    }

    /// `localizedDescription` 은 "The operation couldn't be completed" 로 뭉개진다.
    /// 원인을 가르는 건 도메인·코드다 (권한 거부·세션 한도·비호환 기기가 전부 다른 코드).
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let nsError = error as NSError
        emit("세션 종료: \(nsError.domain) code=\(nsError.code) — \(error.localizedDescription)")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        emit("재개")
    }

    func sessionWasSuspended(_ session: NISession) {
        emit("일시중단 (앱이 백그라운드로 갔거나 UWB 자원을 뺏겼다)")
    }

    // MARK: - Private Function

    private func emit(_ message: String) {
        Task { @MainActor in onEvent(message) }
    }

    /// 프로세스마다 달라지는 `hashValue` 는 쓸 수 없다 — 두 기기의 값을 맞대볼 수 없다.
    private static func fingerprint(of data: Data) -> String {
        SHA256.hash(data: data).prefix(3)
            .map { String(format: "%02X", $0) }
            .joined()
    }
}
#endif
