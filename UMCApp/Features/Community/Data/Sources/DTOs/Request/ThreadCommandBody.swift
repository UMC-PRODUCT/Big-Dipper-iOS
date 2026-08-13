//
//  ThreadCommandBody.swift
//  CommunityData
//

import Foundation

/// STOMP SEND destination.
///
/// 구독은 유저별 두 개가 전부고, 발행만 스레드별 경로를 쓴다.
enum ThreadDestination {

    static let events = "/user/queue/community/threads/events"
    static let errors = "/user/queue/errors"

    static func messages(_ threadId: String) -> String {
        "/app/community/threads/\(threadId)/messages"
    }

    static func read(_ threadId: String) -> String {
        "/app/community/threads/\(threadId)/read"
    }

    /// 반응은 토글 destination 이 없다 — 방향이 경로로 갈린다.
    static func reactionAdd(_ threadId: String, _ messageId: String) -> String {
        "\(messagePath(threadId, messageId))/reactions/add"
    }

    static func reactionRemove(_ threadId: String, _ messageId: String) -> String {
        "\(messagePath(threadId, messageId))/reactions/remove"
    }

    static func deleteMessage(_ threadId: String, _ messageId: String) -> String {
        "\(messagePath(threadId, messageId))/delete"
    }

    private static func messagePath(_ threadId: String, _ messageId: String) -> String {
        "\(messages(threadId))/\(messageId)"
    }
}

/// SEND 의 `x-command-id` 헤더 값.
///
/// 서버는 canonical lowercase UUID 만 받는다. `UUID().uuidString` 은 대문자라 그대로 쓰면 거절당한다.
enum ThreadCommandID {

    static func generate() -> String {
        UUID().uuidString.lowercased()
    }
}

/// `/app/community/threads/{id}/messages` 본문.
///
/// 1차 PR 은 텍스트만 보내므로 `type` 은 상수다. 이미지 전송이 붙으면 파라미터로 승격한다.
/// `mentionedMemberIds`/`replyToId` 도 같은 이유로 아직 싣지 않는다 — 서버가 optional 로 받는다.
public struct SendMessageBody: Encodable {

    // MARK: - Property

    public let clientMessageId: String
    public let content: String
    public let fileMetadataIds: [String]
    private let type = "TEXT"

    // MARK: - Init

    public init(clientMessageId: String, content: String, fileMetadataIds: [String]) {
        self.clientMessageId = clientMessageId
        self.content = content
        self.fileMetadataIds = fileMetadataIds
    }
}

/// `/app/community/threads/{id}/read` 본문.
public struct ReadWatermarkBody: Encodable {

    // MARK: - Property

    public let lastReadMessageId: String

    // MARK: - Init

    public init(lastReadMessageId: String) {
        self.lastReadMessageId = lastReadMessageId
    }
}

/// 반응 add/remove 공통 본문.
///
/// 서버가 `@JsonAnySetter` 로 모르는 필드를 잡아내 프레임을 즉시 거절한다.
/// `emoji` 외에는 무엇도 싣지 않는다 — 편의 필드 하나가 반응 전체를 죽인다.
public struct ReactionBody: Encodable {

    // MARK: - Property

    public let emoji: String

    // MARK: - Init

    public init(emoji: String) {
        self.emoji = emoji
    }
}

/// 본문이 필요 없는 명령(삭제)용 빈 객체.
///
/// 대상은 destination 경로가 전부 지목하므로 실을 값이 없다. 그래도 프레임 본문은 있어야 해서
/// `{}` 를 만든다 — 프로퍼티가 없는 `Encodable` 이 그 결과를 낸다.
public struct EmptyCommandBody: Encodable {

    // MARK: - Init

    public init() {}
}
