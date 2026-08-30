//
//  WatchSessionProviding.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import WatchConnectivity

// MARK: - WatchUserInfoTransfer

/// 큐에 남아 있는 `transferUserInfo` 항목.
///
/// `WCSessionUserInfoTransfer` 도 직접 만들 수 없어서, 큐 만료 취소를 검증하려면 이 표면까지
/// 대역으로 바꿀 수 있어야 한다.
public protocol WatchUserInfoTransfer: AnyObject {
    var userInfo: [String: Any] { get }
    func cancel()
}

extension WCSessionUserInfoTransfer: WatchUserInfoTransfer {}

// MARK: - WatchSessionProviding

/// ``WatchSessionCoordinator`` 가 실제로 쓰는 `WCSession` 표면만 추린 seam.
///
/// `WCSession` 은 싱글턴(`WCSession.default`)이고 직접 생성할 수 없다. 이 프로토콜이 없으면
/// 활성화 결과·도달성 변화·전송 실패·큐 만료 같은 상태 전이를 테스트에서 결정적으로 재현할
/// 방법이 없다 — 페어링된 워치가 없는 CI 에서는 `isReachable` 이 항상 `false` 다.
///
/// 메서드 이름을 `WCSession` 원본과 다르게 둔 이유: 같은 시그니처로 선언하면 아래 준수
/// 익스텐션의 구현이 자기 자신을 호출한다(무한 재귀). 이름을 분리해 전달만 하면 그 위험이 없다.
public protocol WatchSessionProviding: AnyObject {

    /// 현재 기기가 WatchConnectivity 를 지원하는지 여부 (iPad 등은 false).
    var isSupported: Bool { get }

    /// 활성화가 끝났는지 여부. 전송 API 는 전부 활성화 이후에만 유효하다.
    var isActivated: Bool { get }

    /// 상대 기기가 즉시 메시지를 받을 수 있는 상태인지 여부.
    var isReachable: Bool { get }

    /// 상대가 마지막으로 퍼블리시해 둔 컨텍스트. 콜드런치 시딩에 쓴다.
    var receivedContext: [String: Any] { get }

    /// 아직 전송되지 않은 `transferUserInfo` 큐 항목.
    var outstandingTransfers: [any WatchUserInfoTransfer] { get }

    /// 세션 델리게이트를 연결한다. ``startActivation()`` 전에 호출해야 한다.
    func attach(delegate: any WCSessionDelegate)

    /// 세션 활성화를 시작한다. 완료는 델리게이트 콜백으로 통지된다.
    func startActivation()

    /// 메시지를 즉시 전송한다. 성공 시 `onReply`, 실패 시 `onError` 가 호출된다.
    func send(
        _ message: [String: Any],
        onReply: @escaping ([String: Any]) -> Void,
        onError: @escaping (any Error) -> Void
    )

    /// 애플리케이션 컨텍스트를 갱신한다 (덮어쓰기).
    func apply(applicationContext: [String: Any]) throws

    /// FIFO 큐에 넣는다. 앱이 종료돼도 시스템이 전송을 이어간다.
    func transfer(userInfo: [String: Any])
}

// MARK: - WCSession Conformance

extension WCSession: WatchSessionProviding {

    public var isSupported: Bool { WCSession.isSupported() }

    public var isActivated: Bool { activationState == .activated }

    public var receivedContext: [String: Any] { receivedApplicationContext }

    public var outstandingTransfers: [any WatchUserInfoTransfer] {
        outstandingUserInfoTransfers
    }

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

    public func transfer(userInfo: [String: Any]) {
        transferUserInfo(userInfo)
    }
}
