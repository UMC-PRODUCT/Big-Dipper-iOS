//
//  ThreadMessageResponseDTO.swift
//  CommunityData
//

import Foundation
import CommunityDomain
import UMCFoundation

public struct ThreadMessageFileDTO: Codable {

    // MARK: - Property

    public let fileId: String
    public let fileName: String
    public let fileSize: String
    public let fileUrl: String

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case fileId, fileName, fileSize, fileUrl
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fileId = try container.decodeFlexibleString(forKey: .fileId)
        self.fileName = container.decodeFlexibleStringOrEmpty(forKey: .fileName)
        self.fileSize = container.decodeFlexibleStringOrNil(forKey: .fileSize) ?? "0"
        self.fileUrl = container.decodeFlexibleStringOrEmpty(forKey: .fileUrl)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileId, forKey: .fileId)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(fileUrl, forKey: .fileUrl)
    }

    // MARK: - Computed Property

    public var toDomain: ThreadMessageFile {
        ThreadMessageFile(
            id: fileId,
            fileName: fileName,
            fileSize: fileSize,
            fileURL: fileUrl
        )
    }
}

public struct ThreadMessageMentionDTO: Codable {

    // MARK: - Property

    public let memberId: String
    public let name: String

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case memberId, name
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.memberId = try container.decodeFlexibleString(forKey: .memberId)
        self.name = container.decodeFlexibleStringOrEmpty(forKey: .name)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(name, forKey: .name)
    }

    // MARK: - Computed Property

    public var toDomain: ThreadMessageMention {
        ThreadMessageMention(memberId: memberId, name: name)
    }
}

public struct ThreadMessageReplyDTO: Codable {

    // MARK: - Property

    public let messageId: String
    public let senderName: String
    public let snippet: String

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case messageId, senderName, snippet
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.messageId = try container.decodeFlexibleString(forKey: .messageId)
        self.senderName = container.decodeFlexibleStringOrEmpty(forKey: .senderName)
        self.snippet = container.decodeFlexibleStringOrEmpty(forKey: .snippet)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(snippet, forKey: .snippet)
    }

    // MARK: - Computed Property

    public var toDomain: ThreadMessageReply {
        ThreadMessageReply(messageId: messageId, senderName: senderName, snippet: snippet)
    }
}

public struct ThreadMessageReactionDTO: Codable {

    // MARK: - Property

    public let emoji: String
    public let count: String
    public let reactedByMe: Bool

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case emoji, count, reactedByMe
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.emoji = container.decodeFlexibleStringOrEmpty(forKey: .emoji)
        self.count = container.decodeFlexibleStringOrNil(forKey: .count) ?? "0"
        self.reactedByMe = try container.decodeBoolFlexibleIfPresent(forKey: .reactedByMe) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(count, forKey: .count)
        try container.encode(reactedByMe, forKey: .reactedByMe)
    }

    // MARK: - Computed Property

    public var toDomain: ThreadMessageReaction {
        ThreadMessageReaction(emoji: emoji, count: count, reactedByMe: reactedByMe)
    }
}

/// REST `CommunityThreadMessageResponse` 와 STOMP `CommunityThreadMessageInfo` 를 함께 받는다.
///
/// 서버 `status` 는 값이 `SENT` 하나뿐이라 도메인으로 넘기지 않는다. 삭제 판정은 `deletedAt`.
public struct ThreadMessageDTO: Codable {

    // MARK: - Property

    public let messageId: String
    public let threadId: String
    public let senderId: String
    public let senderName: String
    public let content: String
    public let type: String
    public let files: [ThreadMessageFileDTO]
    public let mentions: [ThreadMessageMentionDTO]
    public let replyTo: ThreadMessageReplyDTO?
    public let reactions: [ThreadMessageReactionDTO]
    public let clientMessageId: String?
    public let createdAt: String
    public let editedAt: String?
    public let deletedAt: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case messageId, threadId, senderId, senderName, content, type
        case files, mentions, replyTo, reactions, clientMessageId
        case createdAt, editedAt, deletedAt
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.messageId = try container.decodeFlexibleString(forKey: .messageId)
        self.threadId = container.decodeFlexibleStringOrEmpty(forKey: .threadId)
        self.senderId = container.decodeFlexibleStringOrEmpty(forKey: .senderId)
        self.senderName = container.decodeFlexibleStringOrEmpty(forKey: .senderName)
        self.content = container.decodeFlexibleStringOrEmpty(forKey: .content)
        self.type = container.decodeFlexibleStringOrEmpty(forKey: .type)
        self.files = try container.decodeIfPresent(
            [ThreadMessageFileDTO].self,
            forKey: .files
        ) ?? []
        self.mentions = try container.decodeIfPresent(
            [ThreadMessageMentionDTO].self,
            forKey: .mentions
        ) ?? []
        self.replyTo = try container.decodeIfPresent(
            ThreadMessageReplyDTO.self,
            forKey: .replyTo
        )
        self.reactions = try container.decodeIfPresent(
            [ThreadMessageReactionDTO].self,
            forKey: .reactions
        ) ?? []
        self.clientMessageId = container.decodeFlexibleStringOrNil(forKey: .clientMessageId)
        self.createdAt = container.decodeFlexibleStringOrEmpty(forKey: .createdAt)
        self.editedAt = container.decodeFlexibleStringOrNil(forKey: .editedAt)
        self.deletedAt = container.decodeFlexibleStringOrNil(forKey: .deletedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(threadId, forKey: .threadId)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(content, forKey: .content)
        try container.encode(type, forKey: .type)
        try container.encode(files, forKey: .files)
        try container.encode(mentions, forKey: .mentions)
        try container.encodeIfPresent(replyTo, forKey: .replyTo)
        try container.encode(reactions, forKey: .reactions)
        try container.encodeIfPresent(clientMessageId, forKey: .clientMessageId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(editedAt, forKey: .editedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }

    // MARK: - Computed Property

    public var toDomain: ThreadMessage {
        ThreadMessage(
            id: messageId,
            threadId: threadId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            // 서버가 타입을 늘려도 대화가 끊기지 않도록 시스템 메시지로 폴백한다.
            type: ThreadMessageType(rawValue: type) ?? .system,
            files: files.map(\.toDomain),
            mentions: mentions.map(\.toDomain),
            replyTo: replyTo?.toDomain,
            reactions: reactions.map(\.toDomain),
            clientMessageId: clientMessageId,
            createdAt: ServerDateTimeConverter.parseUTCDateTime(createdAt) ?? .distantPast,
            editedAt: editedAt.flatMap(ServerDateTimeConverter.parseUTCDateTime),
            deletedAt: deletedAt.flatMap(ServerDateTimeConverter.parseUTCDateTime),
            deliveryState: .sent
        )
    }
}

/// `GET /messages` 응답. 서버는 **최신순**으로 준다.
public struct ThreadMessagePageDTO: Codable {

    // MARK: - Property

    public let messages: [ThreadMessageDTO]
    public let hasMore: Bool
    public let nextBefore: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case messages, hasMore, nextBefore
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.messages = try container.decodeIfPresent(
            [ThreadMessageDTO].self,
            forKey: .messages
        ) ?? []
        self.hasMore = try container.decodeBoolFlexibleIfPresent(forKey: .hasMore) ?? false
        self.nextBefore = container.decodeFlexibleStringOrNil(forKey: .nextBefore)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messages, forKey: .messages)
        try container.encode(hasMore, forKey: .hasMore)
        try container.encodeIfPresent(nextBefore, forKey: .nextBefore)
    }

    // MARK: - Computed Property

    public var toDomain: ThreadMessagePage {
        ThreadMessagePage(
            messages: messages.map(\.toDomain),
            hasMore: hasMore,
            nextBefore: nextBefore
        )
    }
}
