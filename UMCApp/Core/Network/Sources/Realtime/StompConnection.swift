//
//  StompConnection.swift
//  CoreNetwork
//

import Foundation

/// STOMP 연결이 상위로 흘려보내는 사건.
///
/// `reconnected` 는 최초 연결이 아닌 복구 연결에서만 나온다. 상위는 이 신호를 받아
/// REST 백필을 돌린다 — 브로커가 끊긴 동안의 이벤트를 재전송하지 않기 때문이다.
public enum StompEvent: Sendable {
    case connected
    case reconnected
    case message(StompFrame)
    case error(StompFrame)
    case disconnected(Error?)
}

public enum StompConnectionError: Error, Equatable {
    case notConnected
    case missingToken
}

/// 소켓 왕복을 대체할 수 있게 `URLSessionWebSocketTask` 를 최소한으로 감싼 경계.
protocol WebSocketConnecting: Sendable {
    func resume()
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

extension URLSessionWebSocketTask: WebSocketConnecting {}

/// `URLSessionWebSocketTask` 위의 STOMP 1.2 클라이언트.
///
/// 프로토콜 레이어만 담당한다. destination 문자열과 이벤트 의미 해석은 호출자 몫이다.
public actor StompConnection {

    // MARK: - Property

    private let url: URL
    private let tokenStore: TokenStore
    private let makeSocket: @Sendable (URL) -> any WebSocketConnecting

    private var socket: (any WebSocketConnecting)?
    private var continuation: AsyncStream<StompEvent>.Continuation?

    /// 재연결 시 그대로 재전송할 구독 목록 (destination → subscription id)
    private var subscriptions: [String: String] = [:]
    private var subscriptionSequence = 0

    private var isConnected = false
    private var isOpening = false
    private var hasConnectedOnce = false
    private var isStopping = false
    private var reconnectAttempt = 0
    private var receiveLoop: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    // MARK: - Init

    public init(url: URL, tokenStore: TokenStore, session: URLSession = .shared) {
        self.init(url: url, tokenStore: tokenStore) { session.webSocketTask(with: $0) }
    }

    init(
        url: URL,
        tokenStore: TokenStore,
        makeSocket: @escaping @Sendable (URL) -> any WebSocketConnecting
    ) {
        self.url = url
        self.tokenStore = tokenStore
        self.makeSocket = makeSocket
    }

    // MARK: - Static Function

    /// REST base URL 에서 네이티브 STOMP 엔드포인트를 유도한다. SockJS `/ws` 는 쓰지 않는다.
    public static func webSocketURL(base: URL) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.scheme = (base.scheme == "http") ? "ws" : "wss"
        components?.path = "/ws/websocket"
        return components?.url ?? base
    }

    /// 지수 백오프. 1s 에서 시작해 2배씩, 30s 에서 고정.
    public static func backoffSeconds(attempt: Int) -> Double {
        min(30, pow(2, Double(attempt)))
    }

    /// 웹소켓 한 메시지에 프레임이 여러 개 붙어 오므로 NUL 종료자를 경계로 잘라 준다.
    ///
    /// 조각 앞의 EOL(앞 프레임 뒤에 붙은 heartbeat)만 걷어내고 종료자는 남겨,
    /// 프레임 경계 판정과 본문 끝 개행 보존을 디코더에 그대로 맡긴다.
    static func splitFrames(_ data: Data) -> [Data] {
        var segments = data
            .split(separator: 0x00, omittingEmptySubsequences: false)
            .map { Data($0.drop { $0 == 0x0A || $0 == 0x0D }) }

        // 마지막 조각은 종료자 뒤 잔여물이다. 비어 있지 않으면 잘린 프레임이므로 디코더에 넘긴다.
        guard let tail = segments.popLast() else { return [] }

        var frames = segments.map { $0 + Data([0x00]) }
        if !tail.isEmpty { frames.append(tail) }
        return frames
    }

    // MARK: - Function

    public func events() -> AsyncStream<StompEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    public func connect() async {
        // 재연결 타이머와 수동 호출이 겹쳐도 소켓은 하나만 연다.
        guard socket == nil, !isOpening else { return }
        isOpening = true
        defer { isOpening = false }

        isStopping = false

        guard let accessToken = await tokenStore.getAccessToken() else {
            continuation?.yield(.disconnected(StompConnectionError.missingToken))
            scheduleReconnect()
            return
        }

        let socket = makeSocket(url)
        socket.resume()
        self.socket = socket

        startReceiveLoop(on: socket)

        let connectFrame = StompFrame(
            command: .connect,
            headers: [
                "accept-version": "1.2",
                "host": url.host ?? "",
                "heart-beat": "10000,10000",
                "Authorization": "Bearer \(accessToken)"
            ]
        )
        try? await write(connectFrame)
    }

    public func subscribe(destination: String) async {
        if subscriptions[destination] == nil {
            subscriptions[destination] = "sub-\(subscriptionSequence)"
            subscriptionSequence += 1
        }
        guard isConnected, let identifier = subscriptions[destination] else { return }

        let frame = StompFrame(
            command: .subscribe,
            headers: ["id": identifier, "destination": destination, "ack": "auto"]
        )
        try? await write(frame)
    }

    public func send(destination: String, headers: [String: String], body: Data) async throws {
        guard isConnected else { throw StompConnectionError.notConnected }

        var allHeaders = headers
        allHeaders["destination"] = destination
        allHeaders["content-type"] = "application/json"
        allHeaders["content-length"] = String(body.count)

        try await write(StompFrame(command: .send, headers: allHeaders, body: body))
    }

    public func disconnect() async {
        isStopping = true
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveLoop?.cancel()
        receiveLoop = nil
        isConnected = false
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    // MARK: - Private Function

    private func write(_ frame: StompFrame) async throws {
        guard let socket = self.socket else { throw StompConnectionError.notConnected }
        // 서버가 텍스트 프레임을 기대하므로 UTF-8 문자열로 보낸다. 헤더 이스케이프는 코덱이 처리했다.
        guard let text = String(data: frame.encoded(), encoding: .utf8) else {
            throw StompConnectionError.notConnected
        }
        try await socket.send(.string(text))
    }

    private func startReceiveLoop(on socket: any WebSocketConnecting) {
        receiveLoop?.cancel()
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let message = try await socket.receive()
                    await self.handle(message)
                } catch {
                    await self.handleDisconnect(error)
                    return
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let payload): data = payload
        @unknown default: return
        }

        for segment in Self.splitFrames(data) {
            guard let frame = try? StompFrame.decode(segment) else { continue }
            await process(frame)
        }
    }

    private func process(_ frame: StompFrame) async {
        switch frame.command {
        case .connected:
            isConnected = true
            reconnectAttempt = 0
            // 상위가 이벤트를 받은 시점에는 이미 구독이 살아 있어야 백필과 실시간 수신이 안 겹친다.
            await restoreSubscriptions()
            continuation?.yield(hasConnectedOnce ? .reconnected : .connected)
            hasConnectedOnce = true

        case .message:
            continuation?.yield(.message(frame))

        case .error:
            // STOMP 규격상 ERROR 프레임 뒤에는 연결이 닫힌다.
            continuation?.yield(.error(frame))

        default:
            break
        }
    }

    private func restoreSubscriptions() async {
        for destination in subscriptions.keys.sorted() {
            await subscribe(destination: destination)
        }
    }

    private func handleDisconnect(_ error: Error?) {
        guard !isStopping else { return }
        isConnected = false
        socket = nil
        continuation?.yield(.disconnected(error))
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard !isStopping, reconnectTask == nil else { return }
        let delay = Self.backoffSeconds(attempt: reconnectAttempt)
        reconnectAttempt += 1

        reconnectTask = Task { [weak self] in
            // jitter: 동시에 끊긴 클라이언트들이 같은 순간에 몰려 재연결하는 것을 막는다.
            let jitter = Double.random(in: 0...0.3) * delay
            try? await Task.sleep(for: .seconds(delay + jitter))
            guard let self, !Task.isCancelled else { return }
            await self.clearReconnectTask()
            await self.connect()
        }
    }

    private func clearReconnectTask() {
        reconnectTask = nil
    }
}
