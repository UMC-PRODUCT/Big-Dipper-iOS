//
//  WatchMessenger.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 4/24/26.
//

#if canImport(WatchConnectivity)
import WatchConnectivity

/// iOS ↔ watchOS 간 메시지 송수신 인터페이스
///
/// 실제 도메인 페이로드 정의는 후속 이슈에서 추가됩니다.
/// 현재는 WCSession 기반 통신 인프라만 제공합니다.
public protocol WatchMessengerProtocol: Sendable {
    /// 상대방이 reachable 상태일 때 메시지를 즉시 전송합니다.
    func sendMessage(_ message: [String: Any]) async throws

    /// 애플리케이션 컨텍스트를 업데이트합니다.
    /// 상대방이 활성화되지 않은 경우에도 최신 상태를 전달할 수 있습니다.
    func updateApplicationContext(_ context: [String: Any]) throws
}

/// `WatchMessengerProtocol`의 `WCSession` 기반 구현체
public final class WatchMessenger: WatchMessengerProtocol {

    // MARK: - Property

    private let coordinator: WatchSessionCoordinator

    // MARK: - Init

    public init(coordinator: WatchSessionCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - Function

    public func sendMessage(_ message: [String: Any]) async throws {
        try await coordinator.sendMessage(message)
    }

    public func updateApplicationContext(_ context: [String: Any]) throws {
        try coordinator.updateApplicationContext(context)
    }
}
#endif
