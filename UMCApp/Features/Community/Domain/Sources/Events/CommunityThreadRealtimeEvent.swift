//
//  CommunityThreadRealtimeEvent.swift
//  CommunityDomain
//

import Foundation

/// `thread.updated` 가 싣고 오는 부분 갱신.
///
/// 전체 `CommunityThread` 가 아니다 — 고정/알림/미읽음 같은 개인화 필드가 없다.
/// 수신 측은 기존 행의 메타데이터만 덮어쓴다.
public struct ThreadMetadataUpdate: Hashable, Sendable {

    // MARK: - Property

    public let threadId: String
    public let title: String
    public let description: String
    public let category: CommunityThreadCategory
    public let icon: String
    public let memberCount: String
    public let maxMembers: String
    public let updatedAt: Date

    // MARK: - Init

    public init(
        threadId: String,
        title: String,
        description: String,
        category: CommunityThreadCategory,
        icon: String,
        memberCount: String,
        maxMembers: String,
        updatedAt: Date
    ) {
        self.threadId = threadId
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
        self.memberCount = memberCount
        self.maxMembers = maxMembers
        self.updatedAt = updatedAt
    }
}

/// `/user/queue/community/threads/events` 로 오는 서버 이벤트.
///
/// - Important: `commandAcknowledged` 는 **저장 완료 ACK 가 아니다.** best-effort 이고
///   상태 이벤트와 순서 보장도 없다. UI 확정은 반드시 `messageCreated` 로 한다.
public enum CommunityThreadRealtimeEvent: Sendable {
    case commandAcknowledged(
        threadId: String,
        commandId: String,
        messageId: String?,
        clientMessageId: String?,
        deduplicated: Bool
    )
    case messageCreated(threadId: String, message: ThreadMessage, clientMessageId: String?)
    case messageUpdated(threadId: String, message: ThreadMessage)
    case messageDeleted(threadId: String, message: ThreadMessage)
    case reactionChanged(threadId: String, messageId: String, reactions: [ThreadMessageReaction])
    case readUpdated(threadId: String, memberId: String, lastReadMessageId: String)
    case threadInvited(thread: CommunityThread)
    case threadUpdated(update: ThreadMetadataUpdate)
    case threadDeleted(threadId: String, deletedAt: Date)
    case memberKicked(threadId: String, memberId: String, memberCount: String)
    case memberLeft(threadId: String, memberId: String, memberCount: String)
    /// 서버가 나중에 추가한 타입. 무시하되 크래시하지 않는다.
    case unknown(type: String, threadId: String)

    // MARK: - Computed Property

    /// 화면이 자기 스레드 이벤트만 골라내는 데 쓴다.
    public var threadId: String {
        switch self {
        case .commandAcknowledged(let threadId, _, _, _, _): return threadId
        case .messageCreated(let threadId, _, _): return threadId
        case .messageUpdated(let threadId, _): return threadId
        case .messageDeleted(let threadId, _): return threadId
        case .reactionChanged(let threadId, _, _): return threadId
        case .readUpdated(let threadId, _, _): return threadId
        case .threadInvited(let thread): return thread.id
        case .threadUpdated(let update): return update.threadId
        case .threadDeleted(let threadId, _): return threadId
        case .memberKicked(let threadId, _, _): return threadId
        case .memberLeft(let threadId, _, _): return threadId
        case .unknown(_, let threadId): return threadId
        }
    }
}

/// `/user/queue/errors` 로 오는 커맨드 실패.
///
/// 에러가 나도 STOMP 세션은 유지된다. 429 rate-limit 도 이 채널로 온다.
public struct RealtimeCommandError: Error, Hashable, Sendable {

    // MARK: - Property

    public let commandId: String?
    public let clientMessageId: String?
    public let status: String
    public let code: String
    public let message: String
    public let retryable: Bool

    // MARK: - Init

    public init(
        commandId: String?,
        clientMessageId: String?,
        status: String,
        code: String,
        message: String,
        retryable: Bool
    ) {
        self.commandId = commandId
        self.clientMessageId = clientMessageId
        self.status = status
        self.code = code
        self.message = message
        self.retryable = retryable
    }

    // MARK: - Computed Property

    public var isRateLimited: Bool { status == "429" }
}

/// 화면이 구독하는 실시간 신호.
///
/// `reconnected` 는 브로커가 끊긴 동안의 이벤트를 재전송하지 않기 때문에 필요하다.
/// 이 신호를 받은 화면은 REST 로 백필한다.
public enum CommunityRealtimeSignal: Sendable {
    case event(CommunityThreadRealtimeEvent)
    case reconnected
    case commandFailed(RealtimeCommandError)
}
