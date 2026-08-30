//
//  WatchSessionProviding.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/30/26.
//

#if canImport(WatchConnectivity)
import WatchConnectivity

/// `WatchSessionCoordinator`가 실제로 쓰는 `WCSession` 표면만 추린 seam.
///
/// `WCSession`은 싱글턴(`WCSession.default`)이고 직접 생성할 수 없어서, 이 프로토콜 없이는
/// reachability 변화나 전송 실패 같은 상태 전이를 테스트에서 결정적으로 재현할 수 없다.
/// 프로덕션에서는 `WCSession.default`가, 테스트에서는 대역이 주입된다.
///
/// 메서드 이름을 `WCSession`의 원본과 다르게 둔 이유: 동일 시그니처로 선언하면 아래
/// 준수 익스텐션의 구현이 자기 자신을 호출하게 되고, SDK 시그니처(블록 nullability 등)가
/// 바뀌면 준수가 조용히 깨진다. 이름을 분리해 전달(forwarding)만 하면 그 위험이 없다.
public protocol WatchSessionProviding: AnyObject {
    /// 현재 기기가 WatchConnectivity를 지원하는지 여부 (iPad 등은 false).
    var isSupported: Bool { get }

    /// 상대 기기가 즉시 메시지를 받을 수 있는 상태인지 여부.
    var isReachable: Bool { get }

    /// 세션 델리게이트를 연결한다. `startActivation()` 전에 호출해야 한다.
    func attach(delegate: any WCSessionDelegate)

    /// 세션 활성화를 시작한다. 완료는 델리게이트 콜백으로 통지된다.
    func startActivation()

    /// 메시지를 즉시 전송한다. 성공 시 `onReply`, 실패 시 `onError`가 호출된다.
    func send(
        _ message: [String: Any],
        onReply: @escaping ([String: Any]) -> Void,
        onError: @escaping (any Error) -> Void
    )

    /// 애플리케이션 컨텍스트를 갱신한다.
    func apply(applicationContext: [String: Any]) throws
}

// MARK: - WCSession Conformance

extension WCSession: WatchSessionProviding {

    public var isSupported: Bool { WCSession.isSupported() }

    public func attach(delegate: any WCSessionDelegate) {
        self.delegate = delegate
    }

    public func startActivation() {
        activate()
    }

    public func send(
        _ message: [String: Any],
        onReply: @escaping ([String: Any]) -> Void,
        onError: @escaping (any Error) -> Void
    ) {
        sendMessage(message, replyHandler: onReply, errorHandler: onError)
    }

    public func apply(applicationContext: [String: Any]) throws {
        try updateApplicationContext(applicationContext)
    }
}
#endif
