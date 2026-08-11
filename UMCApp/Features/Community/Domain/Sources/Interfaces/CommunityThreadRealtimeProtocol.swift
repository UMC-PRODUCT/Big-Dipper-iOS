//
//  CommunityThreadRealtimeProtocol.swift
//  CommunityDomain
//

import Foundation

/// STOMP 계약.
///
/// 구독 destination 은 스레드별이 아니라 **유저별**(`/user/queue/community/threads/events`)이다.
/// 그래서 연결 소유권은 앱 생명주기에 붙고, 화면은 `threadId` 로 걸러 쓴다.
public protocol CommunityThreadRealtimeProtocol: Sendable {

    /// 연결 + 구독 시작. 이미 연결돼 있으면 no-op.
    ///
    /// **반환 시점에는 아직 연결 전이다** — CONNECTED 를 받기 전에 돌아온다. 직후에 부른
    /// `sendMessage`/`updateReadWatermark` 는 던진다. 화면은 낙관적 전송 + 실패 재시도를 전제한다.
    func start() async

    func stop() async

    /// 모든 스레드의 신호가 섞여 나온다. 화면이 `threadId` 로 필터링한다.
    func signals() async -> AsyncStream<CommunityRealtimeSignal>

    /// - Parameter clientMessageId: canonical lowercase UUID. 서버 멱등 키이자
    ///   `messageCreated` 수신 시 낙관적 항목을 찾는 열쇠다.
    func sendMessage(
        threadId: String,
        clientMessageId: String,
        content: String,
        fileMetadataIds: [String]
    ) async throws

    /// 읽음 워터마크 갱신. 더 작거나 같은 값은 서버가 멱등 no-op 처리한다.
    func updateReadWatermark(threadId: String, lastReadMessageId: String) async throws
}
