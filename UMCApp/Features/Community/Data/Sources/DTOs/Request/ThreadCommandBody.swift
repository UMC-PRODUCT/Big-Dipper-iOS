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
