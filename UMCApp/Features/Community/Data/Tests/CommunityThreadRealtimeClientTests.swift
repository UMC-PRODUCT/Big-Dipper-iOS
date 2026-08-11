//
//  CommunityThreadRealtimeClientTests.swift
//  CommunityDataTests
//

import Foundation
import Synchronization
import Testing
import CommunityDomain
@testable import CommunityData
@testable import CoreNetwork

@Suite("CommunityThreadRealtimeClient — 가짜 소켓 위의 연결 수명주기")
struct CommunityThreadRealtimeClientTests {

    // MARK: - Property

    private static let connectedFrame = "CONNECTED\nversion:1.2\n\n\u{00}"

    private static let acknowledgedEvent = """
        {"eventId":"e-1","type":"command.acknowledged","threadId":"12",\
        "payload":{"commandId":"c-1"}}
        """

    private static let rateLimitError = """
        {"status":"429","code":"RATE_LIMITED","message":"too many","retryable":true}
        """

    // MARK: - Test

    @Test("start() 를 동시에 불러도 연결·구독은 한 벌뿐이고 이벤트가 유실되지 않는다",
          .timeLimit(.minutes(1)))
    func concurrentStartKeepsSingleConsumer() async throws {
        let factory = FakeSocketFactory()
        let client = try makeClient(factory: factory)
        let signals = await client.signals()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { await client.start() }
            }
        }

        let socket = try await firstSocket(factory)
        socket.deliver(Self.connectedFrame)
        await waitUntil { socket.sent(prefix: "SUBSCRIBE").count == 2 }

        // events() 가 두 번 불렸다면 앞 스트림이 죽어 CONNECTED 를 놓치고 여기 도달하지 못한다.
        #expect(factory.sockets.count == 1)
        #expect(socket.sent(prefix: "CONNECT").count == 1)
        let subscribed = socket.sent(prefix: "SUBSCRIBE").joined()
        #expect(subscribed.contains("destination:\(ThreadDestination.events)"))
        #expect(subscribed.contains("destination:\(ThreadDestination.errors)"))

        var received = signals.makeAsyncIterator()
        socket.deliver(message(to: ThreadDestination.events, body: Self.acknowledgedEvent))
        guard case .event(let event) = await received.next() else {
            Issue.record("이벤트 신호가 오지 않음")
            return
        }
        #expect(event.threadId == "12")

        await client.stop()
        if let leftover = await received.next() {
            Issue.record("stop() 뒤에도 신호가 남음: \(leftover)")
        }
    }

    @Test("start() 는 connect() 의 토큰 조회를 기다리지 않는다", .timeLimit(.minutes(1)))
    func startDoesNotAwaitTokenLookup() async throws {
        let factory = FakeSocketFactory()
        let tokenStore = GatedTokenStore()
        let client = try makeClient(factory: factory, tokenStore: tokenStore)

        // connect() 를 start() 안에서 직접 await 하면 이 호출이 게이트에 걸려 영영 돌아오지 않는다.
        await client.start()
        await tokenStore.waitUntilSuspended()

        let stopping = Task { await client.stop() }
        await tokenStore.release()
        await stopping.value

        // 뒤늦게 열린 소켓이 있어도 stop() 이 펌프 종료를 기다렸으므로 살아남지 않는다.
        let live = factory.sockets.filter { !$0.isCancelled }
        #expect(live.isEmpty)
    }

    @Test("stop() 대기 중 끼어든 start() 의 새 연결은 끊기지 않는다", .timeLimit(.minutes(1)))
    func stopKeepsConnectionOpenedWhileWaiting() async throws {
        let factory = FakeSocketFactory()
        let tokenStore = GatedTokenStore()
        let client = try makeClient(factory: factory, tokenStore: tokenStore)
        let signals = await client.signals()

        await client.start()
        await tokenStore.waitUntilSuspended()

        let stopping = Task { await client.stop() }
        // 취소 관찰 = stop() 이 pumpTask 를 이미 비웠다는 뜻. 여기서 건 start() 가 재시작이 된다.
        await waitUntil { tokenStore.isCallerCancelled }
        await client.start()
        await tokenStore.release()
        await stopping.value

        // stop() 이 재시작을 알아채지 못하면 이 소켓을 끊고 구독자까지 finish 해 버린다.
        let live = factory.sockets.filter { !$0.isCancelled }
        let socket = try #require(live.first)
        socket.deliver(Self.connectedFrame)
        await waitUntil { socket.sent(prefix: "SUBSCRIBE").count == 2 }

        var received = signals.makeAsyncIterator()
        socket.deliver(message(to: ThreadDestination.events, body: Self.acknowledgedEvent))
        guard case .event = await received.next() else {
            Issue.record("재시작한 연결에서 이벤트가 오지 않음")
            return
        }

        await client.stop()
    }

    @Test("stop() 이후 start() 는 새 소켓으로 재개된다", .timeLimit(.minutes(1)))
    func restartsAfterStop() async throws {
        let factory = FakeSocketFactory()
        let client = try makeClient(factory: factory)

        await client.start()
        let first = try await firstSocket(factory)
        first.deliver(Self.connectedFrame)
        await waitUntil { first.sent(prefix: "SUBSCRIBE").count == 2 }
        await client.stop()

        let signals = await client.signals()
        await client.start()
        await waitUntil { factory.sockets.count == 2 }
        let second = try #require(factory.sockets.last)
        second.deliver(Self.connectedFrame)
        await waitUntil { second.sent(prefix: "SUBSCRIBE").count == 2 }

        var received = signals.makeAsyncIterator()
        // 두 번째 CONNECTED 는 reconnected 로 오고, 구독은 StompConnection 이 복원한다.
        guard case .reconnected = await received.next() else {
            Issue.record("재연결 신호가 오지 않음")
            return
        }

        second.deliver(message(to: ThreadDestination.events, body: Self.acknowledgedEvent))
        guard case .event = await received.next() else {
            Issue.record("재개 후 이벤트가 오지 않음")
            return
        }

        await client.stop()
    }

    @Test("릴레이가 바꾼 errors destination 도 commandFailed 로 흘러간다",
          .timeLimit(.minutes(1)))
    func routesRelayErrorDestination() async throws {
        let factory = FakeSocketFactory()
        let client = try makeClient(factory: factory)
        let signals = await client.signals()

        await client.start()
        let socket = try await firstSocket(factory)
        socket.deliver(Self.connectedFrame)
        await waitUntil { socket.sent(prefix: "SUBSCRIBE").count == 2 }

        var received = signals.makeAsyncIterator()
        // RabbitMQ/ActiveMQ 릴레이는 `/user/queue/errors` 를 이 모양으로 바꿔 내려보낸다.
        socket.deliver(message(to: "/queue/errors-userabc123", body: Self.rateLimitError))
        // 에러가 봉투 디코더로 새면 첫 신호가 이 이벤트가 되어 곧바로 실패한다 — 매달리지 않는다.
        socket.deliver(message(to: ThreadDestination.events, body: Self.acknowledgedEvent))

        guard case .commandFailed(let failure) = await received.next() else {
            Issue.record("commandFailed 신호가 오지 않음")
            return
        }
        #expect(failure.isRateLimited)

        await client.stop()
    }

    // MARK: - Function

    private func makeClient(
        factory: FakeSocketFactory,
        tokenStore: any TokenStore = StubTokenStore()
    ) throws -> CommunityThreadRealtimeClient {
        let url = try #require(URL(string: "wss://dev.api.umc.it.kr/ws/websocket"))
        let connection = StompConnection(
            url: url,
            tokenStore: tokenStore,
            makeSocket: { _ in factory.make() }
        )
        return CommunityThreadRealtimeClient(connection: connection)
    }

    private func message(to destination: String, body: String) -> String {
        "MESSAGE\ndestination:\(destination)\n\n\(body)\u{00}"
    }

    private func firstSocket(_ factory: FakeSocketFactory) async throws -> FakeSocket {
        await waitUntil { !factory.sockets.isEmpty }
        return try #require(factory.sockets.first)
    }

    /// 펌프가 별도 Task 에서 도는 구조라 결과가 즉시 보이지 않는다. `.timeLimit` 이 상한이다.
    ///
    /// `try?` 가 취소를 삼키므로 직접 확인하지 않으면, timeLimit 이 본문을 취소한 뒤에도
    /// sleep 없는 tight loop 가 되어 테스트가 실패로 끝나지 못하고 코어를 태운다.
    private func waitUntil(_ condition: @Sendable () -> Bool) async {
        while !condition() {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
    }
}

// MARK: - Test Double

/// 실제 소켓 왕복 없이 프레임을 주입·수집하는 가짜 전송로.
///
/// `cancel` 이 대기 중인 `receive()` 를 **동기적으로** 깨워야 실제 소켓 취소와 순서가 같아지므로,
/// actor 대신 `Mutex` 로 상태를 지킨다.
private final class FakeSocket: WebSocketConnecting {

    private typealias MessageContinuation =
        CheckedContinuation<URLSessionWebSocketTask.Message, any Error>

    private struct State {
        var inbox: [URLSessionWebSocketTask.Message] = []
        var sent: [String] = []
        var waiting: MessageContinuation?
        var isCancelled = false
    }

    private let state = Mutex(State())

    var isCancelled: Bool { state.withLock { $0.isCancelled } }

    func sent(prefix: String) -> [String] {
        state.withLock { $0.sent }.filter { $0.hasPrefix(prefix + "\n") }
    }

    func resume() {}

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let waiting = state.withLock { current -> MessageContinuation? in
            current.isCancelled = true
            let waiting = current.waiting
            current.waiting = nil
            return waiting
        }
        waiting?.resume(throwing: CancellationError())
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        guard case .string(let text) = message else { return }
        state.withLock { $0.sent.append(text) }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock { current in
                if current.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if current.inbox.isEmpty {
                    current.waiting = continuation
                } else {
                    continuation.resume(returning: current.inbox.removeFirst())
                }
            }
        }
    }

    /// 서버가 프레임을 밀어 넣은 상황을 재현한다. 수신 루프가 아직 대기 전이면 버퍼에 쌓는다.
    func deliver(_ text: String) {
        let waiting = state.withLock { current -> MessageContinuation? in
            guard let waiting = current.waiting else {
                current.inbox.append(.string(text))
                return nil
            }
            current.waiting = nil
            return waiting
        }
        waiting?.resume(returning: .string(text))
    }
}

/// 재연결이 소켓을 몇 개나 열었는지 세기 위해 매번 새 소켓을 만들고 보관한다.
private final class FakeSocketFactory: Sendable {

    private let created = Mutex<[FakeSocket]>([])

    var sockets: [FakeSocket] { created.withLock { $0 } }

    func make() -> FakeSocket {
        let socket = FakeSocket()
        created.withLock { $0.append(socket) }
        return socket
    }
}

private struct StubTokenStore: TokenStore {

    func getAccessToken() async -> String? { "token-1" }

    func getRefreshToken() async -> String? { nil }

    func save(accessToken: String, refreshToken: String) async throws {}

    func clear() async throws {}
}

/// 토큰 조회를 붙잡아 두는 저장소 — handshake 도중에 멈춘 `connect()` 를 재현한다.
private actor GatedTokenStore: TokenStore {

    private var gate: CheckedContinuation<Void, Never>?
    private var suspensionWaiter: CheckedContinuation<Void, Never>?
    private var isSuspended = false

    /// 게이트에 걸린 Task 가 취소됐는지 — 호출자 밖에서 봐야 하므로 actor 격리 밖에 둔다.
    private let cancelledFlag = Mutex(false)

    nonisolated var isCallerCancelled: Bool { cancelledFlag.withLock { $0 } }

    func getAccessToken() async -> String? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                gate = continuation
                isSuspended = true
                suspensionWaiter?.resume()
                suspensionWaiter = nil
            }
        } onCancel: {
            // 취소만 기록하고 게이트는 계속 붙잡아 둔다 — release() 시점을 테스트가 정한다.
            cancelledFlag.withLock { $0 = true }
        }
        return "token-1"
    }

    func getRefreshToken() async -> String? { nil }

    func save(accessToken: String, refreshToken: String) async throws {}

    func clear() async throws {}

    /// 토큰 조회가 실제로 멈출 때까지 기다린다.
    func waitUntilSuspended() async {
        guard !isSuspended else { return }
        await withCheckedContinuation { suspensionWaiter = $0 }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}
