//
//  StompConnectionTests.swift
//  CoreNetworkTests
//

import Foundation
import Synchronization
import Testing
@testable import CoreNetwork

@Suite("StompConnection — URL 유도와 재연결 백오프")
struct StompConnectionTests {

    @Test("https base URL 은 wss 네이티브 STOMP 엔드포인트로 바뀐다")
    func derivesSecureWebSocketURL() throws {
        let base = try #require(URL(string: "https://dev.api.umc.it.kr"))

        #expect(StompConnection.webSocketURL(base: base).absoluteString
            == "wss://dev.api.umc.it.kr/ws/websocket")
    }

    @Test("http base URL 은 ws 로 바뀐다")
    func derivesPlainWebSocketURL() throws {
        let base = try #require(URL(string: "http://localhost:8080"))

        #expect(StompConnection.webSocketURL(base: base).absoluteString
            == "ws://localhost:8080/ws/websocket")
    }

    @Test("백오프는 1초에서 시작해 2배씩 늘고 30초에서 멈춘다")
    func backoffGrowsAndCaps() {
        #expect(StompConnection.backoffSeconds(attempt: 0) == 1)
        #expect(StompConnection.backoffSeconds(attempt: 1) == 2)
        #expect(StompConnection.backoffSeconds(attempt: 4) == 16)
        #expect(StompConnection.backoffSeconds(attempt: 5) == 30)
        #expect(StompConnection.backoffSeconds(attempt: 50) == 30)
    }
}

@Suite("StompConnection — 프레임 경계 분할")
struct StompFrameSplittingTests {

    @Test("한 메시지에 이어 붙어 온 프레임은 NUL 경계로 나뉜다")
    func splitsConcatenatedFrames() throws {
        let raw = Data("MESSAGE\nid:1\n\na\u{00}\nMESSAGE\nid:2\n\nb\u{00}".utf8)

        let frames = try StompConnection.splitFrames(raw).compactMap { try StompFrame.decode($0) }

        #expect(frames.map { $0.headers["id"] } == ["1", "2"])
        #expect(frames.map(\.bodyString) == ["a", "b"])
    }

    @Test("프레임이 하나뿐이면 그대로 한 조각이다")
    func keepsSingleFrameIntact() throws {
        let raw = Data("MESSAGE\nid:1\n\nbody\n\u{00}".utf8)

        let frames = StompConnection.splitFrames(raw)

        #expect(frames.count == 1)
        #expect(try StompFrame.decode(try #require(frames.first))?.bodyString == "body\n")
    }

    @Test("종료자 뒤 heartbeat 개행은 프레임으로 세지 않는다")
    func ignoresHeartbeatBytes() {
        #expect(StompConnection.splitFrames(Data("MESSAGE\n\n\u{00}\n".utf8)).count == 1)
        #expect(StompConnection.splitFrames(Data("\n".utf8)).isEmpty)
        #expect(StompConnection.splitFrames(Data()).isEmpty)
    }

    @Test("종료자 없이 잘린 잔여 바이트는 조각으로 남아 디코딩에서 걸러진다")
    func keepsTruncatedTailForDecoder() throws {
        let raw = Data("MESSAGE\n\n\u{00}MESSAGE\nid:2".utf8)

        let frames = StompConnection.splitFrames(raw)

        #expect(frames.count == 2)
        #expect(throws: StompFrameError.malformed) {
            try StompFrame.decode(try #require(frames.last))
        }
    }
}

@Suite("StompConnection — 가짜 소켓 위의 연결 동작")
struct StompConnectionBehaviorTests {

    private static let connectedFrame = "CONNECTED\nversion:1.2\n\n\u{00}"

    private func makeConnection(
        socket: FakeWebSocket,
        tokenStore: TokenStore = MockTokenStore(accessToken: "token-1")
    ) throws -> StompConnection {
        let url = try #require(URL(string: "wss://dev.api.umc.it.kr/ws/websocket"))
        return StompConnection(url: url, tokenStore: tokenStore, makeSocket: { _ in socket })
    }

    @Test("connect 는 accept-version·heart-beat·Authorization 을 담은 CONNECT 를 보낸다")
    func sendsConnectFrame() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)

        await connection.connect()

        let sent = try #require(socket.sentTexts.first)
        #expect(sent.hasPrefix("CONNECT\n"))
        #expect(sent.contains("accept-version:1.2"))
        #expect(sent.contains("heart-beat:10000,10000"))
        #expect(sent.contains("host:dev.api.umc.it.kr"))
        #expect(sent.contains("Authorization:Bearer token-1"))

        await connection.disconnect()
    }

    @Test("토큰이 없으면 소켓을 열지 않고 missingToken 으로 끊긴 것을 알린다")
    func reportsMissingToken() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket, tokenStore: MockTokenStore())
        var events = await connection.events().makeAsyncIterator()

        await connection.connect()

        let event = await events.next()
        guard case .disconnected(let error) = event else {
            Issue.record("disconnected 이벤트가 아님: \(String(describing: event))")
            return
        }
        #expect(error as? StompConnectionError == .missingToken)
        #expect(socket.sentTexts.isEmpty)

        await connection.disconnect()
    }

    @Test("토큰 조회 중 disconnect 가 끼어들면 소켓을 열지 않는다")
    func abortsHandshakeInterruptedByDisconnect() async throws {
        let socket = FakeWebSocket()
        let tokenStore = GatedTokenStore()
        let connection = try makeConnection(socket: socket, tokenStore: tokenStore)

        let connecting = Task { await connection.connect() }
        await tokenStore.waitUntilSuspended()
        await connection.disconnect()
        await tokenStore.release()
        await connecting.value

        #expect(socket.sentTexts.isEmpty)
    }

    @Test("CONNECTED 를 받으면 connected, 두 번째부터는 reconnected 를 흘려보낸다")
    func distinguishesReconnection() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)
        var events = await connection.events().makeAsyncIterator()

        await connection.connect()
        socket.deliver(Self.connectedFrame)
        let first = await events.next()
        socket.deliver(Self.connectedFrame)
        let second = await events.next()

        guard case .connected = first else {
            Issue.record("첫 이벤트가 connected 가 아님: \(String(describing: first))")
            return
        }
        guard case .reconnected = second else {
            Issue.record("두 번째 이벤트가 reconnected 가 아님: \(String(describing: second))")
            return
        }

        await connection.disconnect()
    }

    @Test("한 메시지에 붙어 온 MESSAGE 두 개는 이벤트 두 개로 흘러간다")
    func emitsEveryFrameInOneMessage() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)
        var events = await connection.events().makeAsyncIterator()

        await connection.connect()
        socket.deliver(Self.connectedFrame)
        _ = await events.next()
        socket.deliver("MESSAGE\nid:1\n\nfirst\u{00}\nMESSAGE\nid:2\n\nsecond\u{00}")

        var bodies: [String?] = []
        for _ in 0..<2 {
            guard case .message(let frame) = await events.next() else { continue }
            bodies.append(frame.bodyString)
        }
        #expect(bodies == ["first", "second"])

        await connection.disconnect()
    }

    @Test("연결 전 등록한 구독은 CONNECTED 직후 SUBSCRIBE 로 복원된다")
    func restoresSubscriptionsOnConnected() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)
        var events = await connection.events().makeAsyncIterator()

        await connection.connect()
        await connection.subscribe(destination: "/topic/a")
        socket.deliver(Self.connectedFrame)
        _ = await events.next()

        let subscribeFrames = socket.sentTexts.filter { $0.hasPrefix("SUBSCRIBE\n") }
        #expect(subscribeFrames.count == 1)
        #expect(subscribeFrames.first?.contains("destination:/topic/a") == true)
        #expect(subscribeFrames.first?.contains("id:sub-0") == true)

        await connection.disconnect()
    }

    @Test("연결되지 않은 상태의 send 는 notConnected 로 실패한다")
    func rejectsSendBeforeConnected() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)

        await #expect(throws: StompConnectionError.notConnected) {
            try await connection.send(destination: "/app/a", headers: [:], body: Data())
        }
    }

    @Test("연결 후 send 는 destination·content-length 헤더를 붙인다")
    func sendsBodyWithHeaders() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)
        var events = await connection.events().makeAsyncIterator()

        await connection.connect()
        socket.deliver(Self.connectedFrame)
        _ = await events.next()
        try await connection.send(
            destination: "/app/a",
            headers: ["receipt": "r-1"],
            body: Data(#"{"a":1}"#.utf8)
        )

        let sent = try #require(socket.sentTexts.last)
        #expect(sent.hasPrefix("SEND\n"))
        #expect(sent.contains("destination:/app/a"))
        #expect(sent.contains("content-length:7"))
        #expect(sent.contains("content-type:application/json"))
        #expect(sent.contains("receipt:r-1"))
        #expect(sent.hasSuffix("{\"a\":1}\u{00}"))

        await connection.disconnect()
    }

    @Test("disconnect 후에는 수신 루프가 멈춰 프레임을 더 소비하지 않는다")
    func stopsReceiveLoopOnDisconnect() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)
        var events = await connection.events().makeAsyncIterator()

        await connection.connect()
        socket.deliver(Self.connectedFrame)
        _ = await events.next()

        await connection.disconnect()
        socket.deliver("MESSAGE\nid:1\n\nafter\u{00}")

        // 취소된 소켓의 receive() 는 즉시 던진다. 남은 프레임이 그대로면 루프가 끝난 것이다.
        #expect(socket.isCancelled)
        #expect(socket.pendingInboxCount == 1)
    }

    // 회귀 시 next() 가 영영 매달리므로 상한이 필요하다. 없으면 CI 잡이 통째로 멈춘다.
    @Test("events 를 다시 부르면 이전 스트림은 매달리지 않고 종료된다", .timeLimit(.minutes(1)))
    func finishesPreviousEventStream() async throws {
        let socket = FakeWebSocket()
        let connection = try makeConnection(socket: socket)

        let abandoned = await connection.events()
        _ = await connection.events()

        var events = abandoned.makeAsyncIterator()
        #expect(await events.next() == nil)
    }
}

// MARK: - Test Double

/// 실제 소켓 왕복 없이 프레임을 주입·수집하는 가짜 전송로.
///
/// `cancel` 이 대기 중인 `receive()` 를 **동기적으로** 깨워야 실제 소켓 취소와 같은 순서가 재현되므로,
/// actor 대신 `Mutex` 로 상태를 지킨다.
final class FakeWebSocket: WebSocketConnecting {

    private typealias MessageContinuation =
        CheckedContinuation<URLSessionWebSocketTask.Message, any Error>

    private struct State {
        var inbox: [URLSessionWebSocketTask.Message] = []
        var sent: [String] = []
        var waiting: MessageContinuation?
        var isCancelled = false
    }

    private let state = Mutex(State())

    var sentTexts: [String] { state.withLock { $0.sent } }
    var pendingInboxCount: Int { state.withLock { $0.inbox.count } }
    var isCancelled: Bool { state.withLock { $0.isCancelled } }

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

/// 토큰 조회를 붙잡아 두는 저장소 — handshake 도중에 멈춘 `connect()` 를 재현한다.
actor GatedTokenStore: TokenStore {

    private var gate: CheckedContinuation<Void, Never>?
    private var suspensionWaiter: CheckedContinuation<Void, Never>?
    private var isSuspended = false

    func getAccessToken() async -> String? {
        await withCheckedContinuation { continuation in
            gate = continuation
            isSuspended = true
            suspensionWaiter?.resume()
            suspensionWaiter = nil
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
