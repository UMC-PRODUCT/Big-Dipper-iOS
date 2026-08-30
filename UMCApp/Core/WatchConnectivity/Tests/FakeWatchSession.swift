//
//  FakeWatchSession.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/30/26.
//

#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity
@testable import CoreWatchConnectivity

/// `WCSession` 대역.
///
/// 실제 `WCSession`은 싱글턴이라 reachability를 테스트에서 바꿀 수 없고, 페어링된 워치가
/// 없으면 항상 `isReachable == false`다. 그 환경 의존을 제거해 상태 전이를 결정적으로
/// 검증하기 위한 대역이다.
final class FakeWatchSession: WatchSessionProviding {

    // MARK: - Property

    var isSupported: Bool = true
    var isReachable: Bool = false

    /// `send(_:onReply:onError:)`가 돌려줄 결과. 기본값은 빈 응답 성공.
    var sendOutcome: Result<[String: Any], any Error> = .success([:])

    /// `apply(applicationContext:)`가 던질 에러. `nil`이면 성공.
    var applyContextError: (any Error)?

    private(set) weak var attachedDelegate: (any WCSessionDelegate)?
    private(set) var activationCallCount = 0
    private(set) var sentMessages: [[String: Any]] = []
    private(set) var appliedContexts: [[String: Any]] = []

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
}

/// 전송 실패 경로에서 원본 에러가 그대로 올라오는지 확인하기 위한 표식 에러.
struct TransportFailure: Error, Equatable {
    let reason: String
}
#endif
