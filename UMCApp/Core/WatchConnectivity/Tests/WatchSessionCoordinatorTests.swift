//
//  WatchSessionCoordinatorTests.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import Testing
import WatchConnectivity
@testable import CoreWatchConnectivity

/// 세션 어댑터의 상태 전이와 채널 계약.
///
/// 여기서 검증하는 건 `WCSession` 자체가 아니라 **그 위에 얹은 규칙**이다 — 활성화 실패를
/// 「연결됨」으로 오인하지 않는지, 왕복이 필요한 종류가 큐로 새지 않는지, 만료된 출석 요청이
/// 큐에서 빠지는지. 이 규칙이 무너지면 화면은 정상인데 전송만 조용히 죽는다.
@MainActor
@Suite("WatchSessionCoordinator — 상태 전이 · 채널 계약")
struct WatchSessionCoordinatorTests {

    // MARK: - Fixture

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeState(isSignedIn: Bool = true) -> WatchSessionState {
        WatchSessionState(
            isSignedIn: isSignedIn,
            schedules: [],
            notices: [],
            generatedAt: now
        )
    }

    private func makeRequest(measuredAt: Date) -> WatchAttendanceRequest {
        WatchAttendanceRequest(
            scheduleId: "42",
            latitude: 37.5,
            longitude: 127.0,
            locationVerified: true,
            measuredAt: measuredAt
        )
    }

    private func makeResult() -> WatchAttendanceResult {
        WatchAttendanceResult(
            scheduleId: "42",
            status: "ATTENDED",
            decidedAt: now,
            reason: nil
        )
    }

    private func makeCoordinator(
        _ configure: (FakeWatchSession) -> Void = { _ in }
    ) -> (WatchSessionCoordinator, FakeWatchSession) {
        let session = FakeWatchSession()
        configure(session)
        return (WatchSessionCoordinator(session: session), session)
    }

    // MARK: - Activation

    @Test("activate() 는 델리게이트를 붙인 뒤 활성화를 시작한다")
    func activateAttachesDelegate() {
        let (coordinator, session) = makeCoordinator()

        coordinator.activate()

        #expect(session.attachedDelegate === coordinator)
        #expect(session.activationCallCount == 1)
    }

    @Test("미지원 기기에서는 활성화를 시도하지 않는다")
    func activateSkipsWhenUnsupported() {
        let (coordinator, session) = makeCoordinator { $0.isSupported = false }

        coordinator.activate()

        #expect(session.attachedDelegate == nil)
        #expect(session.activationCallCount == 0)
    }

    @Test("활성화 실패는 도달성까지 함께 내린다")
    func failedActivationClearsReachability() {
        let (coordinator, _) = makeCoordinator()

        coordinator.applyActivation(false, reachable: true, seeded: nil)

        #expect(coordinator.isActivated == false)
        // 「도달 가능」인데 전송은 `.sessionNotActivated` 로 죽는 상태를 만들지 않는다.
        #expect(coordinator.isReachable == false)
    }

    @Test("콜드런치 컨텍스트가 첫 스냅샷을 시딩한다")
    func activationSeedsReceivedState() {
        let (coordinator, _) = makeCoordinator()
        let state = makeState()

        coordinator.applyActivation(true, reachable: true, seeded: .sessionState(state))

        #expect(coordinator.isActivated)
        #expect(coordinator.isReachable)
        #expect(coordinator.receivedState == state)
    }

    @Test("이미 최신 스냅샷이 있으면 시딩이 덮어쓰지 않는다")
    func seedingDoesNotOverwriteFresherState() {
        let (coordinator, _) = makeCoordinator()
        let fresh = makeState(isSignedIn: true)
        let stale = makeState(isSignedIn: false)

        coordinator.applyReceivedContext(.sessionState(fresh))
        coordinator.applyActivation(true, reachable: true, seeded: .sessionState(stale))

        #expect(coordinator.receivedState == fresh)
    }

    @Test("활성화 전 도달성 변화는 무시된다")
    func reachabilityRequiresActivation() {
        let (coordinator, _) = makeCoordinator()

        coordinator.applyReachability(true)
        #expect(coordinator.isReachable == false)

        coordinator.applyActivation(true, reachable: false, seeded: nil)
        coordinator.applyReachability(true)
        #expect(coordinator.isReachable)
    }

    // MARK: - Request

    @Test("requestSync 는 상태 응답을 그대로 돌려준다")
    func requestSyncReturnsState() async throws {
        let state = makeState()
        let (coordinator, session) = makeCoordinator()
        session.sendOutcome = .success(try WatchEnvelope.encode(WatchReply.state(state)))

        #expect(try await coordinator.requestSync() == state)
        #expect(session.sentMessages.count == 1)
    }

    @Test("상대가 실패를 응답하면 원인을 그대로 올린다")
    func requestSyncSurfacesRemoteFailure() async throws {
        let (coordinator, session) = makeCoordinator()
        session.sendOutcome = .success(
            try WatchEnvelope.encode(WatchReply.failure(.init(reason: .notSignedIn)))
        )

        await #expect {
            _ = try await coordinator.requestSync()
        } throws: { error in
            guard case WatchConnectivityError.remote(let failure) = error else { return false }
            return failure.reason == .notSignedIn
        }
    }

    @Test("요청과 어긋난 응답은 unexpectedReply 다")
    func requestSyncRejectsMismatchedReply() async throws {
        let (coordinator, session) = makeCoordinator()
        session.sendOutcome = .success(try WatchEnvelope.encode(WatchReply.ack))

        await #expect {
            _ = try await coordinator.requestSync()
        } throws: { error in
            guard case WatchConnectivityError.unexpectedReply(.ack) = error else { return false }
            return true
        }
    }

    @Test("활성화 전 전송은 sessionNotActivated 로 막힌다")
    func sendRequiresActivation() async {
        let (coordinator, session) = makeCoordinator { $0.isActivated = false }

        await #expect {
            _ = try await coordinator.requestSync()
        } throws: { error in
            guard case WatchConnectivityError.sessionNotActivated = error else { return false }
            return true
        }
        #expect(session.sentMessages.isEmpty)
    }

    @Test("도달 불가면 전송을 시도하지 않는다 — 호출자가 큐로 넘길 신호다")
    func sendRequiresReachability() async {
        let (coordinator, session) = makeCoordinator { $0.isReachable = false }

        await #expect {
            _ = try await coordinator.requestSync()
        } throws: { error in
            guard case WatchConnectivityError.notReachable = error else { return false }
            return true
        }
        #expect(session.sentMessages.isEmpty)
    }

    @Test("WCError 가 아닌 전송 실패는 원본을 감싸 올린다")
    func transportFailureKeepsUnderlyingError() async {
        let (coordinator, session) = makeCoordinator()
        session.sendOutcome = .failure(TransportFailure(reason: "socket"))

        await #expect {
            _ = try await coordinator.requestSync()
        } throws: { error in
            guard
                case WatchConnectivityError.transportFailure(let underlying) = error,
                let failure = underlying as? TransportFailure
            else { return false }
            return failure.reason == "socket"
        }
    }

    @Test("WCError 코드는 도메인 에러로 분류된다")
    func wcErrorMapsToDomainError() async {
        let (coordinator, session) = makeCoordinator()
        session.sendOutcome = .failure(
            NSError(
                domain: WCError.errorDomain,
                code: WCError.Code.payloadTooLarge.rawValue
            )
        )

        await #expect {
            _ = try await coordinator.requestSync()
        } throws: { error in
            guard case WatchConnectivityError.payloadTooLarge = error else { return false }
            return true
        }
    }

    @Test("requestAttendance 는 판정 결과를 돌려준다")
    func requestAttendanceReturnsResult() async throws {
        let result = makeResult()
        let (coordinator, session) = makeCoordinator()
        session.sendOutcome = .success(
            try WatchEnvelope.encode(WatchReply.attendance(result))
        )

        let received = try await coordinator.requestAttendance(makeRequest(measuredAt: now))
        #expect(received == result)
    }

    @Test("notifyAttendanceChanged 는 ack 만 정상으로 본다")
    func notifyAttendanceRequiresAck() async throws {
        let (coordinator, session) = makeCoordinator()
        session.sendOutcome = .success(try WatchEnvelope.encode(WatchReply.ack))
        try await coordinator.notifyAttendanceChanged(makeResult())

        session.sendOutcome = .success(
            try WatchEnvelope.encode(WatchReply.state(makeState()))
        )
        await #expect {
            try await coordinator.notifyAttendanceChanged(self.makeResult())
        } throws: { error in
            guard case WatchConnectivityError.unexpectedReply = error else { return false }
            return true
        }
    }

    // MARK: - Context

    @Test("publishSessionState 는 봉투를 컨텍스트로 올린다")
    func publishSessionStateAppliesContext() throws {
        let (coordinator, session) = makeCoordinator()
        let state = makeState()

        try coordinator.publishSessionState(state)

        let applied = try #require(session.appliedContexts.first)
        let message = try WatchEnvelope.decode(WatchMessage.self, from: applied)
        #expect(message == .sessionState(state))
    }

    @Test("활성화 전에는 컨텍스트를 올리지 않는다")
    func publishSessionStateRequiresActivation() {
        let (coordinator, session) = makeCoordinator { $0.isActivated = false }

        #expect(throws: WatchConnectivityError.self) {
            try coordinator.publishSessionState(self.makeState())
        }
        #expect(session.appliedContexts.isEmpty)
    }

    // MARK: - Queue

    @Test("읽음 확인은 큐로 보낸다")
    func enqueueAcceptsNoticeRead() throws {
        let (coordinator, session) = makeCoordinator()
        let read = WatchNoticeRead(noticeId: "7", readAt: now)

        try coordinator.enqueue(.noticeRead(read))

        #expect(session.transfers.count == 1)
        #expect(coordinator.pendingMessages == [.noticeRead(read)])
    }

    @Test(
        "왕복이 필요하거나 최신 1건만 의미 있는 종류는 큐를 거부한다",
        arguments: [
            WatchMessage.syncRequest,
            WatchMessage.sessionState(
                WatchSessionState(
                    isSignedIn: true,
                    schedules: [],
                    notices: [],
                    generatedAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ),
            WatchMessage.attendanceChanged(
                WatchAttendanceResult(
                    scheduleId: "42",
                    status: "ATTENDED",
                    decidedAt: nil,
                    reason: nil
                )
            ),
        ]
    )
    func enqueueRejectsRoundTripChannels(message: WatchMessage) {
        let (coordinator, session) = makeCoordinator()

        #expect(throws: WatchConnectivityError.self) {
            try coordinator.enqueue(message)
        }
        #expect(session.transfers.isEmpty)
    }

    @Test("디코딩되지 않는 큐 항목은 조용히 건너뛴다")
    func pendingMessagesSkipsUndecodable() throws {
        let (coordinator, session) = makeCoordinator()
        session.seedTransfer(["p": Data("nope".utf8)])
        try coordinator.enqueue(.attendanceRequest(makeRequest(measuredAt: now)))

        #expect(coordinator.pendingMessages.count == 1)
    }

    @Test("180분을 넘긴 출석 요청만 큐에서 취소한다 — 경계값은 유효")
    func purgeExpiredQueueRespectsBoundary() throws {
        let (coordinator, session) = makeCoordinator()
        let expired = makeRequest(measuredAt: now - WatchAttendanceRequest.maxQueueAge - 1)
        let boundary = makeRequest(measuredAt: now - WatchAttendanceRequest.maxQueueAge)
        try coordinator.enqueue(.attendanceRequest(expired))
        try coordinator.enqueue(.attendanceRequest(boundary))
        try coordinator.enqueue(.noticeRead(.init(noticeId: "7", readAt: now)))

        let purged = coordinator.purgeExpiredQueue(now: now)

        #expect(purged == [expired])
        #expect(session.transfers.map(\.isCancelled) == [true, false, false])
    }

    // MARK: - Receive

    @Test("transferUserInfo 수신은 도착 순서대로 스트림에 흐른다")
    func receivedUserInfoPreservesOrder() async throws {
        let (coordinator, _) = makeCoordinator()
        let first = WatchNoticeRead(noticeId: "1", readAt: now)
        let second = WatchNoticeRead(noticeId: "2", readAt: now)

        coordinator.ingest(userInfo: try WatchEnvelope.encode(WatchMessage.noticeRead(first)))
        coordinator.ingest(userInfo: try WatchEnvelope.encode(WatchMessage.noticeRead(second)))
        coordinator.ingest(userInfo: ["p": Data("nope".utf8)])

        var received: [WatchMessage] = []
        for await message in coordinator.receivedUserInfo() {
            received.append(message)
            if received.count == 2 { break }
        }

        #expect(received == [.noticeRead(first), .noticeRead(second)])
    }

    @Test("핸들러 미등록 요청에도 응답은 정확히 한 번 돌아간다")
    func unhandledRequestStillReplies() async throws {
        let (coordinator, _) = makeCoordinator()
        let payload = try WatchEnvelope.encode(WatchMessage.syncRequest)

        #expect(await reply(to: payload, on: coordinator) == .failure(.init(reason: .unsupportedRequest)))
    }

    @Test("손상된 봉투는 hop 없이 malformedPayload 로 응답한다")
    func malformedRequestRepliesImmediately() async {
        let (coordinator, _) = makeCoordinator()

        #expect(
            await reply(to: ["p": Data("nope".utf8)], on: coordinator)
                == .failure(.init(reason: .malformedPayload))
        )
    }

    @Test("더 새로운 스키마는 손상과 구분해 응답한다 — 업데이트 안내의 근거다")
    func futureSchemaRepliesWithVersion() async {
        let (coordinator, _) = makeCoordinator()
        let future = WatchSchema.currentVersion + 1
        let json = Data(#"{"kind":"syncRequest","version":\#(future)}"#.utf8)

        #expect(
            await reply(to: ["p": json], on: coordinator)
                == .failure(.init(reason: .unsupportedSchemaVersion, message: "v\(future)"))
        )
    }

    @Test("등록된 핸들러의 응답이 그대로 회신된다")
    func registeredHandlerReplyIsForwarded() async throws {
        let (coordinator, _) = makeCoordinator()
        let state = makeState()
        coordinator.setRequestHandler { _ in .state(state) }

        let payload = try WatchEnvelope.encode(WatchMessage.syncRequest)
        #expect(await reply(to: payload, on: coordinator) == .state(state))
    }

    // MARK: - Function

    /// `[String: Any]` 는 Sendable 이 아니라 continuation 밖으로 못 내보낸다. 클로저 안에서
    /// 봉투를 벗겨 값 타입만 꺼낸다.
    private func reply(
        to request: [String: Any],
        on coordinator: WatchSessionCoordinator
    ) async -> WatchReply? {
        await withCheckedContinuation { continuation in
            coordinator.handle(request: request) { raw in
                continuation.resume(
                    returning: try? WatchEnvelope.decode(WatchReply.self, from: raw)
                )
            }
        }
    }
}
