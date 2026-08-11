//
//  RealtimeEnvelopeDTO.swift
//  CommunityData
//

import Foundation
import CommunityDomain
import UMCFoundation
import os.log

private let logger = Logger(subsystem: "UMCApp", category: "CommunityRealtime")

/// `/user/queue/community/threads/events` 의 이벤트 봉투.
///
/// 타입별 payload 모양이 달라 봉투가 직접 분기해 도메인 이벤트로 만든다. 중간 payload 타입을
/// 11개 만드는 것보다 이쪽이 읽기 쉽고, 새 타입이 와도 `.unknown` 으로 흡수된다.
public struct RealtimeEnvelopeDTO: Decodable {

    // MARK: - Property

    public let eventId: String
    public let type: String
    public let threadId: String
    public let event: CommunityThreadRealtimeEvent

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case eventId, type, threadId, occurredAt, payload
    }

    enum PayloadKeys: String, CodingKey {
        case commandId, messageId, clientMessageId, deduplicated
        case message, reactions
        case memberId, lastReadMessageId, memberCount
        case thread, threadId, title, description, category, icon, maxMembers
        case updatedAt, deletedAt
    }

    // MARK: - Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventId = try container.decodeFlexibleString(forKey: .eventId)
        let type = container.decodeFlexibleStringOrEmpty(forKey: .type)
        let threadId = container.decodeFlexibleStringOrEmpty(forKey: .threadId)

        let payload = try container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
        let event: CommunityThreadRealtimeEvent

        switch type {
        case "command.acknowledged":
            event = .commandAcknowledged(
                threadId: threadId,
                commandId: payload.decodeFlexibleStringOrEmpty(forKey: .commandId),
                messageId: payload.decodeFlexibleStringOrNil(forKey: .messageId),
                clientMessageId: payload.decodeFlexibleStringOrNil(forKey: .clientMessageId),
                deduplicated: try payload.decodeBoolFlexibleIfPresent(forKey: .deduplicated)
                    ?? false
            )

        case "message.created":
            let message = try payload.decode(ThreadMessageDTO.self, forKey: .message)
            // 봉투와 메시지 양쪽에 실릴 수 있다. 있는 쪽에서 읽는다.
            event = .messageCreated(
                threadId: threadId,
                message: message.toDomain,
                clientMessageId: payload.decodeFlexibleStringOrNil(forKey: .clientMessageId)
                    ?? message.clientMessageId
            )

        case "message.updated":
            let message = try payload.decode(ThreadMessageDTO.self, forKey: .message)
            event = .messageUpdated(threadId: threadId, message: message.toDomain)

        case "message.deleted":
            let message = try payload.decode(ThreadMessageDTO.self, forKey: .message)
            event = .messageDeleted(threadId: threadId, message: message.toDomain)

        case "reaction.changed":
            let reactions = try payload.decodeLossyArray(
                ThreadMessageReactionDTO.self,
                forKey: .reactions
            )
            event = .reactionChanged(
                threadId: threadId,
                messageId: payload.decodeFlexibleStringOrEmpty(forKey: .messageId),
                reactions: reactions.map(\.toDomain)
            )

        case "read.updated":
            event = .readUpdated(
                threadId: threadId,
                memberId: payload.decodeFlexibleStringOrEmpty(forKey: .memberId),
                lastReadMessageId: payload.decodeFlexibleStringOrEmpty(
                    forKey: .lastReadMessageId
                )
            )

        case "thread.invited":
            let thread = try payload.decode(CommunityThreadDTO.self, forKey: .thread)
            event = .threadInvited(thread: thread.toDomain)

        case "thread.updated":
            let category = payload.decodeFlexibleStringOrEmpty(forKey: .category)
            let updatedAt = payload.decodeFlexibleStringOrEmpty(forKey: .updatedAt)
            event = .threadUpdated(update: ThreadMetadataUpdate(
                threadId: payload.decodeFlexibleStringOrNil(forKey: .threadId) ?? threadId,
                title: payload.decodeFlexibleStringOrEmpty(forKey: .title),
                description: payload.decodeFlexibleStringOrEmpty(forKey: .description),
                category: CommunityThreadCategory(rawValue: category) ?? .free,
                icon: payload.decodeFlexibleStringOrEmpty(forKey: .icon),
                memberCount: payload.decodeFlexibleStringOrNil(forKey: .memberCount) ?? "0",
                maxMembers: payload.decodeFlexibleStringOrNil(forKey: .maxMembers) ?? "0",
                updatedAt: ServerDateTimeConverter.parseUTCDateTime(updatedAt) ?? .distantPast
            ))

        case "thread.deleted":
            let deletedAt = payload.decodeFlexibleStringOrEmpty(forKey: .deletedAt)
            event = .threadDeleted(
                threadId: payload.decodeFlexibleStringOrNil(forKey: .threadId) ?? threadId,
                deletedAt: ServerDateTimeConverter.parseUTCDateTime(deletedAt) ?? Date()
            )

        case "member.kicked":
            event = .memberKicked(
                threadId: threadId,
                memberId: payload.decodeFlexibleStringOrEmpty(forKey: .memberId),
                memberCount: payload.decodeFlexibleStringOrNil(forKey: .memberCount) ?? "0"
            )

        case "member.left":
            event = .memberLeft(
                threadId: threadId,
                memberId: payload.decodeFlexibleStringOrEmpty(forKey: .memberId),
                memberCount: payload.decodeFlexibleStringOrNil(forKey: .memberCount) ?? "0"
            )

        default:
            event = .unknown(type: type, threadId: threadId)
        }

        // threadId 가 비면 화면의 threadId 필터에 걸리지 않아 아무 데도 도착하지 않는다.
        // 빈 문자열로 채워 흘려보내면 추적 불가능한 유실이 되므로 여기서 끊고 로그를 남긴다.
        guard !event.threadId.isEmpty else {
            logger.error(
                """
                threadId 없는 이벤트를 버립니다 \
                type=\(type, privacy: .public) eventId=\(eventId, privacy: .public)
                """
            )
            throw DecodingError.dataCorruptedError(
                forKey: .threadId,
                in: container,
                debugDescription: "Missing threadId for event type \(type)"
            )
        }

        self.eventId = eventId
        self.type = type
        self.threadId = threadId
        self.event = event
    }
}

/// `/user/queue/errors` 프레임. 에러가 나도 STOMP 세션은 유지된다.
public struct RealtimeErrorDTO: Decodable {

    // MARK: - Property

    public let commandId: String?
    public let clientMessageId: String?
    public let status: String
    public let code: String
    public let message: String
    public let retryable: Bool

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case commandId, clientMessageId, status, code, message, retryable
    }

    // MARK: - Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.commandId = container.decodeFlexibleStringOrNil(forKey: .commandId)
        self.clientMessageId = container.decodeFlexibleStringOrNil(forKey: .clientMessageId)
        self.status = container.decodeFlexibleStringOrNil(forKey: .status) ?? "0"
        self.code = container.decodeFlexibleStringOrEmpty(forKey: .code)
        self.message = container.decodeFlexibleStringOrEmpty(forKey: .message)
        self.retryable = try container.decodeBoolFlexibleIfPresent(forKey: .retryable) ?? false
    }

    // MARK: - Computed Property

    public var toDomain: RealtimeCommandError {
        RealtimeCommandError(
            commandId: commandId,
            clientMessageId: clientMessageId,
            status: status,
            code: code,
            message: message,
            retryable: retryable
        )
    }
}
