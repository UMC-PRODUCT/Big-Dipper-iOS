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
        // 대입은 첫 중단점보다 **앞**이어야 한다. 사이에 await 가 하나라도 있으면 두 번째 호출이
        // 같은 가드를 통과해 `events()` 를 다시 열고, 단일 소비자용인 앞 스트림을 죽인다.
        guard pumpTask == nil else { return }

        pumpTask = Task { [weak self] in
            guard let self else { return }

            // 같은 Task 안에서 순차로 await 하므로 스트림 등록이 connect() 보다 먼저임이 확정된다.
            // 순서가 뒤집히면 CONNECTED 가 구독 없는 스트림으로 흘러 최초 SUBSCRIBE 를 놓친다.
            let events = await connection.events()
            guard !Task.isCancelled else { return }

            await connection.connect()
            for await event in events {
                await self.handle(event)
            }
        }
    }

    public func stop() async {
        let pump = pumpTask
        pumpTask = nil
        pump?.cancel()
        // 취소 직전에 펌프가 connect() 로 진입했을 수 있다. 먼저 끝내지 않으면 뒤늦은 connect() 가
        // disconnect() 뒤에 소켓을 되살려 아무도 취소하지 않는 재연결 루프가 남는다.
        await pump?.value
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
    /// `x-command-id` 는 서버가 요구하는 네이티브 헤더로 매 호출 새 값이 나간다.
    /// 재시도 멱등은 이 헤더가 아니라 호출자가 유지하는 `clientMessageId` 가 담당한다.
    private func send(destination: String, body: some Encodable) async throws {
        try await connection.send(
            destination: destination,
            headers: ["x-command-id": ThreadCommandID.generate()],
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
            emitCommandFailure(from: frame)

        case .disconnected:
            break
        }
    }

    /// 두 구독이 한 채널로 들어오므로 destination 헤더로 갈라 낸다.
    private func handleMessage(_ frame: StompFrame) {
        let destination = frame.headers["destination"] ?? ""

        // Spring 심플 브로커는 `/user/queue/errors` 로 복원해 주지만, RabbitMQ/ActiveMQ 릴레이는
        // `/queue/errors-user{sessionId}` 로 내려보낸다. suffix 로 잡으면 릴레이에서 전부 샌다.
        if destination.contains("/errors") {
            emitCommandFailure(from: frame)
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

    private func emitCommandFailure(from frame: StompFrame) {
        do {
            let failure = try decoder.decode(RealtimeErrorDTO.self, from: frame.body)
            emit(.commandFailed(failure.toDomain))
        } catch {
            // ERROR 프레임 본문은 평문인 경우가 많아 디코딩이 자주 실패한다. 인증 실패처럼
            // 재연결이 계속 깨지는 상황을 추적할 단서가 원문뿐이라 그대로 남긴다 — 토큰은 안 실린다.
            logger.error(
                """
                에러 프레임을 버립니다 \
                message=\(frame.headers["message"] ?? "-", privacy: .public) \
                body=\(frame.bodyString ?? "<non-utf8>", privacy: .public) \
                reason=\(String(describing: error), privacy: .public)
                """
            )
        }
    }

    private func emit(_ signal: CommunityRealtimeSignal) {
        for continuation in continuations.values {
            continuation.yield(signal)
        }
    }
}
