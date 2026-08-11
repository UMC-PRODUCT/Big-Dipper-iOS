//
//  CommunityThreadRealtimeClient.swift
//  CommunityData
//

import Foundation
import CommunityDomain
import CoreNetwork
import os.log

private let logger = Logger(subsystem: "UMCApp", category: "CommunityRealtime")

/// 커뮤니티 STOMP 클라이언트.
///
/// 구독 destination 이 유저별이라 스레드 화면마다 연결을 열 수 없다. 이 객체 하나가 앱 생명주기
/// 동안 연결을 들고, 모든 스레드의 신호를 한 스트림으로 흘린다. 화면은 `threadId` 로 거른다.
///
/// 재연결은 `StompConnection` 이 처리하고, 여기서는 `.reconnected` 를 그대로 흘려보낸다.
/// 끊긴 동안 놓친 이벤트는 화면이 REST 로 백필해야 한다 — STOMP 는 이력을 재생하지 않는다.
public actor CommunityThreadRealtimeClient: CommunityThreadRealtimeProtocol {

    // MARK: - Property

    private let connection: StompConnection
    private let decoder = JSONDecoder()

    private var pumpTask: Task<Void, Never>?
    private var deduplicator = EventDeduplicator()
    private var continuations: [UUID: AsyncStream<CommunityRealtimeSignal>.Continuation] = [:]

    // MARK: - Init

    public init(connection: StompConnection) {
        self.connection = connection
    }

    // MARK: - CommunityThreadRealtimeProtocol

    public func start() async {
        guard pumpTask == nil else { return }

        // `events()` 는 단일 소비자 전용이고 이 앱의 유일한 호출 지점이다. connect() 보다
        // 먼저 열어 두지 않으면 CONNECTED 가 구독 없는 스트림으로 흘러 최초 구독을 통째로 놓친다.
        let events = await connection.events()

        pumpTask = Task { [weak self] in
            for await event in events {
                await self?.handle(event)
            }
        }

        await connection.connect()
    }

    public func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        await connection.disconnect()

        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }

    public func signals() async -> AsyncStream<CommunityRealtimeSignal> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    public func sendMessage(
        threadId: String,
        clientMessageId: String,
        content: String,
        fileMetadataIds: [String]
    ) async throws {
        let body = SendMessageBody(
            clientMessageId: clientMessageId,
            content: content,
            fileMetadataIds: fileMetadataIds
        )
        try await send(destination: ThreadDestination.messages(threadId), body: body)
    }

    public func updateReadWatermark(threadId: String, lastReadMessageId: String) async throws {
        try await send(
            destination: ThreadDestination.read(threadId),
            body: ReadWatermarkBody(lastReadMessageId: lastReadMessageId)
        )
    }

    // MARK: - Function

    /// SEND 프레임 발행.
    ///
    /// `x-command-id` 는 서버가 요구하는 네이티브 헤더로, 명령 단위 멱등 키다.
    private func send(destination: String, body: some Encodable) async throws {
        try await connection.send(
            destination: destination,
            headers: [
                "content-type": "application/json",
                "x-command-id": ThreadCommandID.generate()
            ],
            body: try JSONEncoder().encode(body)
        )
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func handle(_ event: StompEvent) async {
        switch event {
        case .connected:
            await connection.subscribe(destination: ThreadDestination.events)
            await connection.subscribe(destination: ThreadDestination.errors)

        case .reconnected:
            // 구독 복구는 StompConnection 이 이 이벤트를 내보내기 전에 끝낸다.
            // 여기서 다시 구독하면 같은 id 로 SUBSCRIBE 가 중복 발행된다. 공백만 알린다.
            emit(.reconnected)

        case .message(let frame):
            handleMessage(frame)

        case .error(let frame):
            // STOMP ERROR 프레임은 세션을 끝낸다. 재연결은 StompConnection 이 이어서 한다.
            emitCommandFailure(from: frame.body)

        case .disconnected:
            break
        }
    }

    /// 두 구독이 한 채널로 들어오므로 destination 헤더로 갈라 낸다.
    private func handleMessage(_ frame: StompFrame) {
        let destination = frame.headers["destination"] ?? ""

        if destination.hasSuffix("/errors") {
            emitCommandFailure(from: frame.body)
            return
        }

        do {
            let envelope = try decoder.decode(RealtimeEnvelopeDTO.self, from: frame.body)
            // 서버 재시도로 같은 이벤트가 두 번 올 수 있다. 두 번째는 버린다.
            guard deduplicator.shouldProcess(envelope.eventId) else { return }

            emit(.event(envelope.event))
        } catch {
            logger.error("이벤트 프레임을 버립니다 \(String(describing: error), privacy: .public)")
        }
    }

    private func emitCommandFailure(from body: Data) {
        do {
            emit(.commandFailed(try decoder.decode(RealtimeErrorDTO.self, from: body).toDomain))
        } catch {
            logger.error("에러 프레임을 버립니다 \(String(describing: error), privacy: .public)")
        }
    }

    private func emit(_ signal: CommunityRealtimeSignal) {
        for continuation in continuations.values {
            continuation.yield(signal)
        }
    }
}
