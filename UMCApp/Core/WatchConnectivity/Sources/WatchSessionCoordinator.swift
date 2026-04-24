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

    private var session: WCSession { .default }

    // MARK: - Init

    public override init() {
        super.init()
    }

    // MARK: - Function

    /// WCSession을 활성화합니다. 앱 시작 시 한 번 호출합니다.
    public func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// 상대방이 reachable 상태일 때 메시지를 즉시 전송합니다.
    public func sendMessage(_ message: [String: Any]) async throws {
        guard session.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.sendMessage(message, replyHandler: nil) { error in
                continuation.resume(throwing: error)
            }
        }
    }

    /// 애플리케이션 컨텍스트를 업데이트합니다.
    public func updateApplicationContext(_ context: [String: Any]) throws {
        try session.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        isActivated = activationState == .activated
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        isReachable = session.isReachable
    }

#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}

// MARK: - Error

public enum WatchConnectivityError: Error {
    case notReachable
    case sessionNotActivated
}
#endif
