//
//  WatchSessionCoordinator.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 4/24/26.
//

import Foundation
import Observation
import WatchConnectivity

// MARK: - WatchRequestHandler

/// 왕복 요청 처리기.
///
/// `async` 인 이유는 iPhone 쪽 처리가 서버 왕복이라 본질적으로 비동기이기 때문이다.
/// **핸들러 자신이 타임아웃을 걸 책임이 있다** — 여기서 오래 붙들면 송신자는
/// `messageReplyTimedOut`(7012)만 받고 원인을 모른다.
public typealias WatchRequestHandler = @Sendable (WatchMessage) async -> WatchReply

// MARK: - WatchSessionCoordinator

/// WCSession 활성화 · 상태 · 타입 안전 송수신을 모두 소유하는 어댑터.
///
/// **`@MainActor` 인 이유**: 관측 상태를 SwiftUI 가 읽는데 `WCSessionDelegate` 콜백은 임의
/// 스레드에서 온다. MainActor 격리 클래스는 암묵적으로 `Sendable` 이라 격리 경계도 함께 정리된다.
///
/// 델리게이트 메서드는 전부 `nonisolated` 이며 **동기적으로 디코딩한 뒤** MainActor 로 hop 한다.
/// 디코딩을 hop 뒤로 미루면 `[String: Any]`(non-Sendable)가 격리 경계를 넘어야 한다.
@MainActor
@Observable
public final class WatchSessionCoordinator: NSObject, WCSessionDelegate {

    // MARK: - Property

    public private(set) var isActivated: Bool = false
    public private(set) var isReachable: Bool = false

    /// 상대가 마지막으로 퍼블리시한 스냅샷.
    ///
    /// 활성화가 끝나는 시점(`activationDidCompleteWith`)에 `receivedApplicationContext` 로
    /// **시딩된다.** 이미 도착해 있던 컨텍스트에는 델리게이트 콜백이 다시 오지 않아, 시딩이
    /// 없으면 워치 콜드런치 화면이 빈다.
    public private(set) var receivedState: WatchSessionState?

    @ObservationIgnored
    private var requestHandler: WatchRequestHandler?

    /// `transferUserInfo` 수신 스트림. `init` 에서 미리 만들어 델리게이트가 **hop 없이** 바로
    /// yield 한다 — MainActor 잡 큐는 우선순위 큐라, hop 을 거치면 백그라운드 wake 로 들어온
    /// 항목이 포그라운드 항목에 추월당해 도착 순서가 뒤바뀐다.
    ///
    /// 버퍼는 `.unbounded` 다 — 읽음 확인은 건별로 전부 도달해야 해서 메모리보다 유실이 나쁘다.
    /// 대신 아무도 구독하지 않으면 무한히 쌓인다.
    @ObservationIgnored
    private let userInfoStream: AsyncStream<WatchMessage>

    @ObservationIgnored
    private let userInfoContinuation: AsyncStream<WatchMessage>.Continuation

    private var session: WCSession { .default }

    // MARK: - Init

    public override init() {
        let (stream, continuation) = AsyncStream<WatchMessage>.makeStream()
        userInfoStream = stream
        userInfoContinuation = continuation
        super.init()
    }

    // MARK: - Function

    /// WCSession 을 활성화한다. 앱 시작 시 한 번 호출한다.
    public func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// 최신 스냅샷을 요청한다.
    public func requestSync() async throws -> WatchSessionState {
        let reply = try await sendMessage(.syncRequest)
        switch reply {
        case .state(let state):
            return state
        case .failure(let failure):
            throw WatchConnectivityError.remote(failure)
        case .ack, .attendance:
            throw WatchConnectivityError.unexpectedReply(reply)
        }
    }

    /// GPS 출석을 iPhone 에 위임한다. 오프라인이면 `.notReachable` 이므로 호출자가
    /// ``enqueue(_:)`` 로 넘긴다.
    public func requestAttendance(
        _ request: WatchAttendanceRequest
    ) async throws -> WatchAttendanceResult {
        let reply = try await sendMessage(.attendanceRequest(request))
        switch reply {
        case .attendance(let result):
            return result
        case .failure(let failure):
            throw WatchConnectivityError.remote(failure)
        case .ack, .state:
            throw WatchConnectivityError.unexpectedReply(reply)
        }
    }

    /// 출석 결과 변경을 상대에게 즉시 알린다. 응답 `.ack` 는 도달 확인 용도로만 쓴다.
    public func notifyAttendanceChanged(_ result: WatchAttendanceResult) async throws {
        let reply = try await sendMessage(.attendanceChanged(result))
        switch reply {
        case .ack:
            return
        case .failure(let failure):
            throw WatchConnectivityError.remote(failure)
        case .state, .attendance:
            throw WatchConnectivityError.unexpectedReply(reply)
        }
    }

    /// 세션 스냅샷을 퍼블리시한다 (덮어쓰기).
    public func publishSessionState(_ state: WatchSessionState) throws {
        try requireActivated()
        do {
            let payload = try WatchEnvelope.encode(WatchMessage.sessionState(state))
            try session.updateApplicationContext(payload)
        } catch let error as WatchConnectivityError {
            throw error
        } catch {
            throw WatchConnectivityError.from(error)
        }
    }

    /// FIFO 큐에 넣는다. 앱이 종료돼도 시스템이 전송을 계속하므로 자체 큐 저장소를 두지 않는다.
    public func enqueue(_ message: WatchMessage) throws {
        switch message {
        case .attendanceRequest, .noticeRead:
            break
        case .syncRequest, .sessionState, .attendanceChanged:
            // 왕복 응답이 필요하거나 최신 1건만 의미 있는 종류다. 큐에 넣으면 응답이 유실되거나
            // 오래된 스냅샷이 뒤늦게 도착한다.
            throw WatchConnectivityError.unsupportedChannel(message)
        }
        try requireActivated()
        session.transferUserInfo(try WatchEnvelope.encode(message))
    }

    /// 아직 전송되지 않은 큐 항목.
    ///
    /// - Important: **관측 대상이 아니다.** `outstandingUserInfoTransfers` 는 `@Observable` 이
    ///   추적하지 못해, SwiftUI 가 바인딩해도 한 번 그린 뒤 영원히 갱신되지 않는다. 호출 시점의
    ///   스냅샷이므로 화면 캡션은 ``purgeExpiredQueue(now:)`` 의 반환값이나 타이머로 갱신한다.
    public var pendingMessages: [WatchMessage] {
        session.outstandingUserInfoTransfers.compactMap {
            try? WatchEnvelope.decode(WatchMessage.self, from: $0.userInfo)
        }
    }

    /// `measuredAt` 기준 180분이 지난 출석 요청을 큐에서 취소한다.
    ///
    /// 보내도 수신 시각으로 판정되어 결석이 확정되므로 왕복이 무의미하다.
    /// - Returns: 취소를 **시도한** 요청들. 이미 전송이 시작된 항목은 취소가 보장되지 않는다.
    ///   호출자는 이 개수만큼 「사유 제출」 안내를 띄운다.
    @discardableResult
    public func purgeExpiredQueue(now: Date = Date()) -> [WatchAttendanceRequest] {
        var purged: [WatchAttendanceRequest] = []
        for transfer in session.outstandingUserInfoTransfers {
            guard
                let message = try? WatchEnvelope.decode(
                    WatchMessage.self, from: transfer.userInfo
                ),
                case .attendanceRequest(let request) = message,
                request.isExpired(now: now)
            else { continue }
            transfer.cancel()
            purged.append(request)
        }
        return purged
    }

    /// 왕복 요청 처리기를 등록한다. 등록 전에 도착한 요청에는 `.unsupportedRequest` 로 즉시 응답한다.
    public func setRequestHandler(_ handler: @escaping WatchRequestHandler) {
        requestHandler = handler
    }

    /// `transferUserInfo` 로 도착한 메시지 스트림 (FIFO).
    ///
    /// 구독 전에 도착한 항목도 스트림 버퍼에 남아 있다가 구독 즉시 흘러나온다 — 시스템은 앱을
    /// 백그라운드로 깨워 배달하므로 화면이 스트림을 열기 전에 읽음 확인이 도착할 수 있다.
    ///
    /// - Note: 앱당 한 번만 구독한다. `AsyncStream` 은 이터레이터가 하나뿐이라, 두 번째
    ///   구독자는 첫 구독자가 소비하고 남은 것만 본다.
    public func receivedUserInfo() -> AsyncStream<WatchMessage> {
        userInfoStream
    }

    // MARK: - Private

    private func requireActivated() throws {
        guard WCSession.isSupported() else {
            throw WatchConnectivityError.notSupported
        }
        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }
    }

    /// 응답은 클로저 안에서 디코딩한다 — `[String: Any]` 를 continuation 밖으로 내보내면
    /// non-Sendable 값이 격리 경계를 넘는다.
    private func sendMessage(_ message: WatchMessage) async throws -> WatchReply {
        try requireActivated()
        guard session.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        let payload = try WatchEnvelope.encode(message)

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(payload) { raw in
                do {
                    let reply = try WatchEnvelope.decode(WatchReply.self, from: raw)
                    continuation.resume(returning: reply)
                } catch {
                    continuation.resume(throwing: error)
                }
            } errorHandler: { error in
                continuation.resume(throwing: WatchConnectivityError.from(error))
            }
        }
    }

    // MARK: - WCSessionDelegate

    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // WCSession 은 Sendable 이 아니다. hop 하기 전에 값만 읽어 둔다.
        let activated = activationState == .activated
        let reachable = session.isReachable
        // `receivedApplicationContext` 는 활성화가 끝난 뒤에야 채워진다. 활성화는 비동기라
        // `activate()` 직후에 읽으면 빈 딕셔너리를 받아 시딩이 조용히 무산된다.
        let context: [String: Any] = activated ? session.receivedApplicationContext : [:]
        let seeded = try? WatchEnvelope.decode(WatchMessage.self, from: context)
        Task { @MainActor in
            self.isActivated = activated
            self.isReachable = reachable
            // 델리게이트 콜백이 이미 더 최신 컨텍스트를 넣었다면 덮어쓰지 않는다.
            if case .sessionState(let state)? = seeded, self.receivedState == nil {
                self.receivedState = state
            }
        }
    }

    public nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }

    /// `replyHandler` 는 송신자의 타임아웃(7012) 안에 **정확히 한 번** 호출돼야 한다.
    /// early return 과 `Task` 가 상호 배타적인 형태라 「한 번만 호출」 장치가 따로 필요 없다.
    public nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        nonisolated(unsafe) let reply = replyHandler

        // 실패는 hop 없이 즉시 응답한다.
        let decoded: WatchMessage
        do {
            decoded = try WatchEnvelope.decode(WatchMessage.self, from: message)
        } catch WatchConnectivityError.unsupportedSchemaVersion(let version) {
            // 손상이 아니라 상대가 더 새로운 스키마를 쓴다는 신호다. 「손상」으로 뭉개면
            // 상대는 업데이트가 필요하다는 사실을 알 수 없다.
            reply(
                WatchEnvelope.encodeFallback(
                    .failure(
                        .init(reason: .unsupportedSchemaVersion, message: "v\(version)")
                    )
                )
            )
            return
        } catch {
            reply(WatchEnvelope.encodeFallback(.failure(.init(reason: .malformedPayload))))
            return
        }

        Task { @MainActor in
            guard let handler = self.requestHandler else {
                reply(WatchEnvelope.encodeFallback(.failure(.init(reason: .unsupportedRequest))))
                return
            }
            reply(WatchEnvelope.encodeFallback(await handler(decoded)))
        }
    }

    public nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard
            let message = try? WatchEnvelope.decode(
                WatchMessage.self, from: applicationContext
            ),
            case .sessionState(let state) = message
        else { return }
        Task { @MainActor in
            self.receivedState = state
        }
    }

    public nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        guard let message = try? WatchEnvelope.decode(WatchMessage.self, from: userInfo) else {
            return
        }
        // hop 하지 않는다 — continuation 은 Sendable 이고 yield 순서를 그대로 보존한다.
        userInfoContinuation.yield(message)
    }

#if os(iOS)
    /// 사용자가 다른 워치로 갈아타는 중이다. 이 세션으로는 더 보낼 수 없으므로 상태를 내린다 —
    /// 남겨 두면 화면은 「연결됨」인데 전송만 조용히 실패한다.
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.isActivated = false
            self.isReachable = false
        }
    }

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}

// MARK: - WatchConnectivityError + WCError

extension WatchConnectivityError {

    /// `WCSession` 콜백의 `NSError` 를 도메인 에러로 분류한다.
    ///
    /// 이 분류가 무너지면 화면은 원인 불문 「전송 오류」가 되고, 큐로 넘겨야 할 상황(도달 불가)과
    /// 스냅샷을 줄여야 할 상황(페이로드 초과)을 구분하지 못한다.
    public static func from(_ error: Error) -> WatchConnectivityError {
        if let error = error as? WatchConnectivityError { return error }

        let nsError = error as NSError
        guard
            nsError.domain == WCError.errorDomain,
            let code = WCError.Code(rawValue: nsError.code)
        else {
            return .transportFailure(underlying: error)
        }

        switch code {
        case .notReachable:
            return .notReachable
        case .payloadTooLarge:
            return .payloadTooLarge
        case .messageReplyTimedOut:
            return .replyTimedOut
        case .sessionNotActivated:
            return .sessionNotActivated
        default:
            return .transportFailure(underlying: error)
        }
    }
}
