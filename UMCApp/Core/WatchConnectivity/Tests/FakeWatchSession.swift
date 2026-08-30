//
//  FakeWatchSession.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import WatchConnectivity
@testable import CoreWatchConnectivity

// MARK: - FakeUserInfoTransfer

/// `WCSessionUserInfoTransfer` 대역. 취소 여부만 관측한다.
final class FakeUserInfoTransfer: WatchUserInfoTransfer {

    let userInfo: [String: Any]
    private(set) var isCancelled = false

    init(userInfo: [String: Any]) {
        self.userInfo = userInfo
    }

    func cancel() {
        isCancelled = true
    }
}

// MARK: - FakeWatchSession

/// `WCSession` 대역.
///
/// 실제 `WCSession` 은 싱글턴이라 활성화 결과·도달성을 테스트에서 바꿀 수 없고, 페어링된
/// 워치가 없는 CI 에서는 `isReachable` 이 항상 `false` 다. 그 환경 의존을 걷어내 상태 전이와
/// 전송 실패 경로를 결정적으로 검증하기 위한 대역이다.
final class FakeWatchSession: WatchSessionProviding {

    // MARK: - Property

    var isSupported: Bool = true
    var isActivated: Bool = true
    var isReachable: Bool = true
    var receivedContext: [String: Any] = [:]

    /// ``send(_:onReply:onError:)`` 가 돌려줄 결과. 기본값은 빈 응답 성공.
    var sendOutcome: Result<[String: Any], any Error> = .success([:])

    /// ``apply(applicationContext:)`` 가 던질 에러. `nil` 이면 성공.
    var applyContextError: (any Error)?

    private(set) weak var attachedDelegate: (any WCSessionDelegate)?
    private(set) var activationCallCount = 0
    private(set) var sentMessages: [[String: Any]] = []
    private(set) var appliedContexts: [[String: Any]] = []
    private(set) var transfers: [FakeUserInfoTransfer] = []

    var outstandingTransfers: [any WatchUserInfoTransfer] { transfers }

    // MARK: - Function

    /// 큐에 미리 항목을 심는다. `enqueue` 를 거치지 않는 손상 페이로드도 넣을 수 있어야 한다.
    func seedTransfer(_ userInfo: [String: Any]) {
        transfers.append(FakeUserInfoTransfer(userInfo: userInfo))
    }

    // MARK: - WatchSessionProviding

    func attach(delegate: any WCSessionDelegate) {
        attachedDelegate = delegate
    }

    func startActivation() {
        activationCallCount += 1
    }

    func send(
        _ message: [String: Any],
        onReply: @escaping ([String: Any]) -> Void,
        onError: @escaping (any Error) -> Void
    ) {
        sentMessages.append(message)
        switch sendOutcome {
        case .success(let reply):
            onReply(reply)
        case .failure(let error):
            onError(error)
        }
    }

    func apply(applicationContext: [String: Any]) throws {
        if let applyContextError {
            throw applyContextError
        }
        appliedContexts.append(applicationContext)
    }

    func transfer(userInfo: [String: Any]) {
        seedTransfer(userInfo)
    }
}

// MARK: - TransportFailure

/// 전송 실패 경로에서 원본 에러가 그대로 올라오는지 확인하기 위한 표식 에러.
struct TransportFailure: Error, Equatable {
    let reason: String
}
