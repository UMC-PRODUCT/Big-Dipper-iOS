//
//  WatchSessionCoordinatorTests.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/30/26.
//

#if canImport(WatchConnectivity)
import Foundation
import Testing
import WatchConnectivity
@testable import CoreWatchConnectivity

@Suite("WatchSessionCoordinator — 활성화·reachability 상태 전이")
struct WatchSessionCoordinatorActivationTests {

    @Test("초기 상태는 비활성·unreachable이다")
    func initialState() {
        let session = FakeWatchSession()
        let coordinator = WatchSessionCoordinator(session: session)

        #expect(coordinator.isActivated == false)
        #expect(coordinator.isReachable == false)
        #expect(session.activationCallCount == 0)
    }

    @Test("activate()는 델리게이트를 연결한 뒤 활성화를 시작한다")
    func activateAttachesDelegateThenStarts() {
        let session = FakeWatchSession()
        let coordinator = WatchSessionCoordinator(session: session)

        coordinator.activate()

        #expect(session.attachedDelegate === coordinator)
        #expect(session.activationCallCount == 1)
    }

    /// iPad처럼 WatchConnectivity를 지원하지 않는 기기에서 `activate()`가 세션을 건드리면
    /// 런타임 예외가 난다. 지원 여부 확인이 사라지지 않았는지 지킨다.
    @Test("미지원 기기에서 activate()는 아무것도 하지 않는다")
    func activateIsNoOpWhenUnsupported() {
        let session = FakeWatchSession()
        session.isSupported = false
        let coordinator = WatchSessionCoordinator(session: session)

        coordinator.activate()

        #expect(session.attachedDelegate == nil)
        #expect(session.activationCallCount == 0)
    }

    @Test("활성화 성공 시 isActivated가 true가 되고 reachability가 세션에서 동기화된다")
    func activationSucceeded() {
        let session = FakeWatchSession()
        session.isReachable = true
        let coordinator = WatchSessionCoordinator(session: session)

        coordinator.applyActivation(state: .activated, error: nil)

        #expect(coordinator.isActivated)
        #expect(coordinator.isReachable)
    }

    @Test(
        "활성화 실패 상태에서는 isActivated가 false다",
        arguments: [WCSessionActivationState.notActivated, .inactive]
    )
    func activationNotCompleted(state: WCSessionActivationState) {
        let session = FakeWatchSession()
        session.isReachable = true
        let coordinator = WatchSessionCoordinator(session: session)

        coordinator.applyActivation(state: state, error: nil)

        #expect(coordinator.isActivated == false)
        #expect(coordinator.isReachable == false)
    }

    /// `.activated`인데 error가 함께 오는 경우 — 상태만 보고 활성화됐다고 판단하면
    /// 이후 전송이 조용히 실패한다.
    @Test("에러를 동반한 활성화는 성공으로 보지 않는다")
    func activationWithErrorIsFailure() {
        let session = FakeWatchSession()
        session.isReachable = true
        let coordinator = WatchSessionCoordinator(session: session)

        coordinator.applyActivation(
            state: .activated,
            error: TransportFailure(reason: "activation denied")
        )

        #expect(coordinator.isActivated == false)
        #expect(coordinator.isReachable == false)
    }

    @Test("활성화 이후 reachability 변경이 상태에 반영된다", arguments: [true, false])
    func reachabilityChange(reachable: Bool) {
        let session = FakeWatchSession()
        let coordinator = WatchSessionCoordinator(session: session)
        coordinator.applyActivation(state: .activated, error: nil)

        coordinator.applyReachability(reachable)

        #expect(coordinator.isReachable == reachable)
    }
}

@Suite("WatchSessionCoordinator — 전송 계약과 에러 경로")
struct WatchSessionCoordinatorTransportTests {

    private func makeActivated(
        reachable: Bool
    ) -> (WatchSessionCoordinator, FakeWatchSession) {
        let session = FakeWatchSession()
        session.isReachable = reachable
        let coordinator = WatchSessionCoordinator(session: session)
        coordinator.applyActivation(state: .activated, error: nil)
        return (coordinator, session)
    }

    @Test("활성화 전 전송은 sessionNotActivated로 막힌다")
    func sendBeforeActivationThrows() async {
        let session = FakeWatchSession()
        session.isReachable = true
        let coordinator = WatchSessionCoordinator(session: session)

        await #expect(throws: WatchConnectivityError.sessionNotActivated) {
            try await coordinator.sendMessage(["ping": true])
        }
        #expect(session.sentMessages.isEmpty)
    }

    @Test("unreachable 상태에서 전송하면 notReachable을 던진다")
    func sendWhileUnreachableThrows() async {
        let (coordinator, session) = makeActivated(reachable: false)

        await #expect(throws: WatchConnectivityError.notReachable) {
            try await coordinator.sendMessage(["ping": true])
        }
        #expect(session.sentMessages.isEmpty)
    }

    /// 원본 구현은 `replyHandler: nil`로 보내 성공 시 continuation이 재개되지 않았다.
    /// 이 테스트는 그 영구 정지 회귀를 막는다 — 깨지면 타임아웃으로 드러난다.
    @Test("reachable 상태의 전송은 응답을 받고 정상 반환한다")
    func sendSucceedsAndResumes() async throws {
        let (coordinator, session) = makeActivated(reachable: true)

        try await coordinator.sendMessage(["ping": true])

        #expect(session.sentMessages.count == 1)
        #expect(session.sentMessages.first?["ping"] as? Bool == true)
    }

    @Test("전송 실패 시 전송 계층의 원본 에러가 그대로 전파된다")
    func sendFailurePropagatesUnderlyingError() async {
        let (coordinator, session) = makeActivated(reachable: true)
        session.sendOutcome = .failure(TransportFailure(reason: "delivery failed"))

        await #expect(throws: TransportFailure(reason: "delivery failed")) {
            try await coordinator.sendMessage(["ping": true])
        }
    }

    @Test("활성화 전 컨텍스트 갱신은 sessionNotActivated로 막힌다")
    func contextBeforeActivationThrows() {
        let session = FakeWatchSession()
        let coordinator = WatchSessionCoordinator(session: session)

        #expect(throws: WatchConnectivityError.sessionNotActivated) {
            try coordinator.updateApplicationContext(["generation": "12"])
        }
        #expect(session.appliedContexts.isEmpty)
    }

    @Test("컨텍스트 갱신은 세션으로 그대로 전달된다")
    func contextIsForwarded() throws {
        let (coordinator, session) = makeActivated(reachable: false)

        try coordinator.updateApplicationContext(["generation": "12"])

        #expect(session.appliedContexts.count == 1)
        #expect(session.appliedContexts.first?["generation"] as? String == "12")
    }

    @Test("컨텍스트 갱신 실패 시 세션 에러가 전파된다")
    func contextErrorPropagates() {
        let (coordinator, session) = makeActivated(reachable: false)
        session.applyContextError = TransportFailure(reason: "context rejected")

        #expect(throws: TransportFailure(reason: "context rejected")) {
            try coordinator.updateApplicationContext(["generation": "12"])
        }
    }
}
#endif
