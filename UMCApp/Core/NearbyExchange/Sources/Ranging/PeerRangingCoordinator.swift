//
//  PeerRangingCoordinator.swift
//  CoreNearbyExchange
//
//  Created by One on 8/16/26.
//

import Foundation
#if canImport(NearbyInteraction)
import NearbyInteraction
#endif

// MARK: - PeerDistance

/// 한 피어와의 실측 거리.
public struct PeerDistance: Sendable, Equatable {

    /// ``DiscoveredPeer/id`` 와 같은 값 (MPC 세션 식별자).
    public let peerID: String
    /// 미터. 범위 밖이거나 아직 못 잡았으면 `nil`.
    public let meters: Double?

    public init(peerID: String, meters: Double?) {
        self.peerID = peerID
        self.meters = meters
    }
}

// MARK: - PeerRangingCoordinator

/// 발견된 피어들과의 UWB 거리를 재는 조율 계층.
///
/// **왜 transport 가 아닌가**: NearbyInteraction 은 데이터를 나르지 못한다. 거리·방향만 준다.
/// 그래서 ``NearbyTransportProtocol`` 구현체가 될 수 없고(그렇게 두면 영원히 구현 불가),
/// transport 옆에 붙어 거리만 보태는 별도 계층이 맞다.
///
/// ## 세션이 피어마다 하나인 이유
///
/// `NINearbyPeerConfiguration(peerToken:)` 은 **상대 토큰 하나**를 받는다. 즉 한 세션은 한
/// 상대와만 레인징한다. 상대가 늘면 세션도 늘고, 세션마다 자기 `discoveryToken` 이 다르다.
/// 그래서 ``makeHandshake(forPeerID:)`` 가 피어별로 세션을 만들어 그 세션의 토큰을 돌려준다.
///
/// ## NI 는 대칭이다
///
/// 양쪽이 **서로의 토큰으로** 세션을 실행해야 값이 나온다. 한쪽만 실행하면 양쪽 다 아무것도
/// 받지 못한다. 2026-08-16 실기기 검증에서 이 조건을 몰라 한참 헤맸다 — 그래서 토큰 교환을
/// 자동화한다. 사용자가 순서를 틀릴 여지를 없애는 것이 이 계층의 존재 이유다.
public final class PeerRangingCoordinator: NSObject, @unchecked Sendable {

    // MARK: - Property

    /// 이 기기가 UWB 레인징을 할 수 있는지. iPhone 11 미만과 iPad 는 `false`.
    public static var isSupported: Bool {
        #if canImport(NearbyInteraction)
        return NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
        #else
        return false
        #endif
    }

    private let stateQueue = DispatchQueue(label: "dev.umc.nearby.ranging")

    #if canImport(NearbyInteraction)
    /// 피어별 세션. 한 세션이 한 상대만 담당한다.
    private var sessionsByPeerID: [String: NISession] = [:]
    /// 델리게이트 콜백이 `NISession` 으로 오므로 역방향도 필요하다.
    private var peerIDsBySession: [ObjectIdentifier: String] = [:]
    #endif

    /// 내 미리보기. 핸드셰이크에 실어 보낸다.
    private var preview: PeerPreview?

    private var continuation: AsyncStream<PeerDistance>.Continuation?

    /// 마지막 실패 원문. 스트림에 에러 채널이 없어 여기 남긴다.
    private var _lastError: String?

    public var lastError: String? {
        stateQueue.sync { _lastError }
    }

    // MARK: - Init

    public override init() {
        super.init()
    }

    deinit {
        stopAll()
    }

    // MARK: - Function

    /// 핸드셰이크에 실을 내 미리보기를 설정한다. 교환 세션 시작 시 호출한다.
    public func start(preview: PeerPreview) {
        stopAll()
        stateQueue.sync {
            self.preview = preview
            self._lastError = nil
        }
    }

    /// 거리 갱신 스트림. 피어마다 값이 바뀔 때마다 흐른다.
    public func distances() -> AsyncStream<PeerDistance> {
        AsyncStream { continuation in
            stateQueue.sync { self.continuation = continuation }
            continuation.onTermination = { [weak self] _ in
                // sync 금지 — finish() 호출 스레드에서 동기 실행된다.
                self?.stateQueue.async { self?.continuation = nil }
            }
        }
    }

    public func stopAll() {
        #if canImport(NearbyInteraction)
        let sessions = stateQueue.sync { () -> [NISession] in
            let current = Array(sessionsByPeerID.values)
            sessionsByPeerID.removeAll()
            peerIDsBySession.removeAll()
            return current
        }
        sessions.forEach { $0.invalidate() }
        #endif
        takeContinuation()?.finish()
    }

    // MARK: - Private Function

    private func takeContinuation() -> AsyncStream<PeerDistance>.Continuation? {
        stateQueue.sync {
            let current = continuation
            continuation = nil
            return current
        }
    }

    private func record(_ message: String) {
        stateQueue.sync { _lastError = message }
    }
}

// MARK: - NearbyHandshakeProviding

extension PeerRangingCoordinator: NearbyHandshakeProviding {

    /// 이 피어 전용 세션을 만들고 그 토큰을 실어 보낸다.
    ///
    /// UWB 미탑재 기기는 토큰 없이 미리보기만 보낸다 — 상대는 목록에 행을 그리되 거리 칸을 비운다.
    public func makeHandshake(forPeerID peerID: String) -> NearbyHandshake? {
        guard let preview = stateQueue.sync(execute: { self.preview }) else { return nil }

        #if canImport(NearbyInteraction)
        guard Self.isSupported else {
            return NearbyHandshake(preview: preview, niToken: nil)
        }

        let session = NISession()
        session.delegate = self
        guard let token = session.discoveryToken,
              let data = try? NSKeyedArchiver.archivedData(
                  withRootObject: token, requiringSecureCoding: true
              ) else {
            session.invalidate()
            record("NI 토큰 생성 실패")
            return NearbyHandshake(preview: preview, niToken: nil)
        }

        stateQueue.sync {
            // 같은 피어로 다시 들어오면 옛 세션을 버린다 — 토큰이 갈리면 레인징이 조용히 실패한다.
            if let existing = sessionsByPeerID[peerID] {
                peerIDsBySession[ObjectIdentifier(existing)] = nil
                existing.invalidate()
            }
            sessionsByPeerID[peerID] = session
            peerIDsBySession[ObjectIdentifier(session)] = peerID
        }
        return NearbyHandshake(preview: preview, niToken: data)
        #else
        return NearbyHandshake(preview: preview, niToken: nil)
        #endif
    }

    /// 상대 토큰으로 레인징을 시작한다.
    public func didReceiveHandshake(_ handshake: NearbyHandshake, fromPeerID peerID: String) {
        #if canImport(NearbyInteraction)
        guard let data = handshake.niToken else { return }   // 상대가 UWB 미탑재
        guard let session = stateQueue.sync(execute: { sessionsByPeerID[peerID] }) else {
            // 내 토큰을 아직 안 만든 피어다. 순서가 어긋난 것이라 무시한다 —
            // 연결 시 makeHandshake 가 먼저 도는 게 정상 흐름이다.
            record("세션 없는 피어의 핸드셰이크: \(peerID)")
            return
        }
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self, from: data
        ) else {
            record("NI 토큰 역직렬화 실패: \(peerID)")
            return
        }
        session.run(NINearbyPeerConfiguration(peerToken: token))
        #endif
    }

    public func didLosePeer(_ peerID: String) {
        #if canImport(NearbyInteraction)
        let session = stateQueue.sync { () -> NISession? in
            guard let session = sessionsByPeerID.removeValue(forKey: peerID) else { return nil }
            peerIDsBySession[ObjectIdentifier(session)] = nil
            return session
        }
        session?.invalidate()
        #endif
        stateQueue.sync { continuation?.yield(PeerDistance(peerID: peerID, meters: nil)) }
    }
}

// MARK: - NISessionDelegate

#if canImport(NearbyInteraction)
extension PeerRangingCoordinator: NISessionDelegate {

    public func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        stateQueue.sync {
            guard let peerID = peerIDsBySession[ObjectIdentifier(session)] else { return }
            continuation?.yield(
                PeerDistance(peerID: peerID, meters: object.distance.map(Double.init))
            )
        }
    }

    /// 범위를 벗어나면 거리를 비운다 — 옛 값이 남아 있으면 지금 가까이 있는 것처럼 보인다.
    public func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        stateQueue.sync {
            guard let peerID = peerIDsBySession[ObjectIdentifier(session)] else { return }
            continuation?.yield(PeerDistance(peerID: peerID, meters: nil))
        }
    }

    public func session(_ session: NISession, didInvalidateWith error: any Error) {
        let peerID = stateQueue.sync { () -> String? in
            let key = ObjectIdentifier(session)
            guard let peerID = peerIDsBySession[key] else { return nil }
            peerIDsBySession[key] = nil
            sessionsByPeerID[peerID] = nil
            return peerID
        }
        record("NI 세션 종료(\(peerID ?? "?")): \(error.localizedDescription)")
        guard let peerID else { return }
        stateQueue.sync { continuation?.yield(PeerDistance(peerID: peerID, meters: nil)) }
    }

    /// 앱이 백그라운드로 가면 NI 가 멈춘다. 값이 굳지 않도록 비운다.
    public func sessionWasSuspended(_ session: NISession) {
        stateQueue.sync {
            guard let peerID = peerIDsBySession[ObjectIdentifier(session)] else { return }
            continuation?.yield(PeerDistance(peerID: peerID, meters: nil))
        }
    }

    public func sessionSuspensionEnded(_ session: NISession) {}
}
#endif
