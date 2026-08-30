//
//  WatchSessionCoordinator.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 4/24/26.
//

#if canImport(WatchConnectivity)
import WatchConnectivity

/// WCSession 활성화 및 상태 관리 코디네이터
///
/// - `activate()` 호출 후 세션이 준비됩니다.
/// - reachability / activation 상태는 내부에서 WCSessionDelegate를 통해 관리합니다.
@Observable
public final class WatchSessionCoordinator: NSObject, WCSessionDelegate {

    // MARK: - Property

    public private(set) var isReachable: Bool = false
    public private(set) var isActivated: Bool = false

    @ObservationIgnored
    private let session: any WatchSessionProviding

    // MARK: - Init

    /// - Parameter session: 기본값은 `WCSession.default`. 테스트에서만 대역을 주입한다.
    public init(session: any WatchSessionProviding = WCSession.default) {
        self.session = session
        super.init()
    }

    // MARK: - Function

    /// WCSession을 활성화합니다. 앱 시작 시 한 번 호출합니다.
    public func activate() {
        guard session.isSupported else { return }
        session.attach(delegate: self)
        session.startActivation()
    }

    /// 상대방이 reachable 상태일 때 메시지를 즉시 전송합니다.
    ///
    /// `replyHandler`를 반드시 넘긴다 — `nil`로 두면 성공 시 아무 콜백도 오지 않아
    /// `withCheckedThrowingContinuation`이 영영 재개되지 않는다(호출자 영구 정지).
    /// 따라서 상대 앱은 `session(_:didReceiveMessage:replyHandler:)`로 응답해야 하며,
    /// 응답하지 않으면 WatchConnectivity가 전달 실패로 `onError`를 호출한다.
    public func sendMessage(_ message: [String: Any]) async throws {
        guard isActivated else {
            throw WatchConnectivityError.sessionNotActivated
        }
        guard session.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            session.send(
                message,
                onReply: { _ in continuation.resume() },
                onError: { continuation.resume(throwing: $0) }
            )
        }
    }

    /// 애플리케이션 컨텍스트를 업데이트합니다.
    ///
    /// 활성화 전에 호출하면 WatchConnectivity가 Swift 에러가 아니라 ObjC 예외를 던져
    /// 앱이 죽으므로, 먼저 활성화 여부를 확인한다.
    public func updateApplicationContext(_ context: [String: Any]) throws {
        guard isActivated else {
            throw WatchConnectivityError.sessionNotActivated
        }
        try session.apply(applicationContext: context)
    }

    // MARK: - State Transition

    /// 활성화 결과를 상태에 반영한다.
    ///
    /// 활성화가 끝나기 전에는 `session.isReachable`이 의미 없는 값이라 읽지 않는다 —
    /// 활성화 성공 시점에 한 번 동기화해야 최초 reachability가 비어 있지 않다.
    func applyActivation(state: WCSessionActivationState, error: (any Error)?) {
        isActivated = state == .activated && error == nil
        isReachable = isActivated ? session.isReachable : false
    }

    /// reachability 변화를 상태에 반영한다.
    func applyReachability(_ reachable: Bool) {
        isReachable = reachable
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        applyActivation(state: activationState, error: error)
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        applyReachability(session.isReachable)
    }

#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}

// MARK: - Error

public enum WatchConnectivityError: Error, Equatable {
    case notReachable
    case sessionNotActivated
}
#endif
