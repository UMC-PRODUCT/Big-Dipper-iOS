//
//  CommunityThreadResponseDTO.swift
//  CommunityData
//

import Foundation
import CommunityDomain
import UMCFoundation

public struct CommunityThreadLastMessageDTO: Codable {

    // MARK: - Property

    public let preview: String
    public let senderName: String
    public let createdAt: String

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case preview, senderName, createdAt
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.preview = container.decodeFlexibleStringOrEmpty(forKey: .preview)
        self.senderName = container.decodeFlexibleStringOrEmpty(forKey: .senderName)
        self.createdAt = container.decodeFlexibleStringOrEmpty(forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preview, forKey: .preview)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(createdAt, forKey: .createdAt)
    }

    // MARK: - Computed Property

    public var toDomain: ThreadLastMessage {
        ThreadLastMessage(
            preview: preview,
            senderName: senderName,
            createdAt: ServerDateTimeConverter.parseUTCDateTime(createdAt) ?? .distantPast
        )
    }
}

/// 요약·상세·`thread.invited` 가 공유하는 스레드 DTO.
///
/// REST 는 ID/수량을 String 으로, STOMP 는 raw number 로 보낸다. `decodeFlexibleString*` 이
/// 양쪽을 흡수하므로 DTO 를 두 벌 만들지 않는다.
public struct CommunityThreadDTO: Codable {

    // MARK: - Property

    public let threadId: String
    public let title: String
    public let description: String
    public let category: String
    public let icon: String
    public let memberCount: String
    public let unreadCount: String
    public let maxMembers: String
    public let isPinned: Bool
    public let isMuted: Bool
    public let isJoined: Bool
    public let myRole: String?
    public let lastMessage: CommunityThreadLastMessageDTO?
    public let createdBy: String
    public let createdAt: String
    public let updatedAt: String
    public let shareUrl: String?
    public let deletedAt: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case threadId, title, description, category, icon
        case memberCount, unreadCount, maxMembers
        case isPinned, isMuted, isJoined, myRole, lastMessage
        case createdBy, createdAt, updatedAt, shareUrl, deletedAt
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.threadId = try container.decodeFlexibleString(forKey: .threadId)
        self.title = container.decodeFlexibleStringOrEmpty(forKey: .title)
        self.description = container.decodeFlexibleStringOrEmpty(forKey: .description)
        self.category = container.decodeFlexibleStringOrEmpty(forKey: .category)
        self.icon = container.decodeFlexibleStringOrEmpty(forKey: .icon)
        self.memberCount = container.decodeFlexibleStringOrNil(forKey: .memberCount) ?? "0"
        self.unreadCount = container.decodeFlexibleStringOrNil(forKey: .unreadCount) ?? "0"
        self.maxMembers = container.decodeFlexibleStringOrNil(forKey: .maxMembers) ?? "0"
        self.isPinned = try container.decodeBoolFlexibleIfPresent(forKey: .isPinned) ?? false
        self.isMuted = try container.decodeBoolFlexibleIfPresent(forKey: .isMuted) ?? false
        self.isJoined = try container.decodeBoolFlexibleIfPresent(forKey: .isJoined) ?? false
        self.myRole = container.decodeFlexibleStringOrNil(forKey: .myRole)
        self.lastMessage = try container.decodeIfPresent(
            CommunityThreadLastMessageDTO.self,
            forKey: .lastMessage
        )
        self.createdBy = container.decodeFlexibleStringOrEmpty(forKey: .createdBy)
        self.createdAt = container.decodeFlexibleStringOrEmpty(forKey: .createdAt)
        self.updatedAt = container.decodeFlexibleStringOrEmpty(forKey: .updatedAt)
        self.shareUrl = container.decodeFlexibleStringOrNil(forKey: .shareUrl)
        self.deletedAt = container.decodeFlexibleStringOrNil(forKey: .deletedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(threadId, forKey: .threadId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(icon, forKey: .icon)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(maxMembers, forKey: .maxMembers)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(isJoined, forKey: .isJoined)
        try container.encodeIfPresent(myRole, forKey: .myRole)
        try container.encodeIfPresent(lastMessage, forKey: .lastMessage)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(shareUrl, forKey: .shareUrl)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }

    // MARK: - Computed Property

    public var toDomain: CommunityThread {
        CommunityThread(
            id: threadId,
            title: title,
            description: description,
            // 서버가 카테고리를 늘려도 리스트 전체가 죽지 않도록 자유로 폴백한다.
            category: CommunityThreadCategory(rawValue: category) ?? .free,
            icon: icon,
            memberCount: memberCount,
            unreadCount: unreadCount,
            maxMembers: maxMembers,
            isPinned: isPinned,
            isMuted: isMuted,
            isJoined: isJoined,
            myRole: myRole.flatMap(ThreadMemberRole.init(rawValue:)),
            lastMessage: lastMessage?.toDomain,
            createdBy: createdBy,
            createdAt: ServerDateTimeConverter.parseUTCDateTime(createdAt) ?? .distantPast,
            updatedAt: ServerDateTimeConverter.parseUTCDateTime(updatedAt) ?? .distantPast,
            shareURL: shareUrl,
            deletedAt: deletedAt.flatMap(ServerDateTimeConverter.parseUTCDateTime)
        )
    }
}

/// `GET /threads` 응답.
///
/// - Important: `q` 가 없으면 `pinned` 는 페이징되지 않고 `total`/`nextOffset` 은 `threads` 만 센다.
public struct CommunityThreadListDTO: Codable {

    // MARK: - Property

    public let pinned: [CommunityThreadDTO]
    public let threads: [CommunityThreadDTO]
    public let nextOffset: String?
    public let total: String

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case pinned, threads, nextOffset, total
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pinned = try container.decodeLossyArray(CommunityThreadDTO.self, forKey: .pinned)
        self.threads = try container.decodeLossyArray(CommunityThreadDTO.self, forKey: .threads)
        self.nextOffset = container.decodeFlexibleStringOrNil(forKey: .nextOffset)
        self.total = container.decodeFlexibleStringOrNil(forKey: .total) ?? "0"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(threads, forKey: .threads)
        try container.encodeIfPresent(nextOffset, forKey: .nextOffset)
        try container.encode(total, forKey: .total)
    }

    // MARK: - Computed Property

    public var toDomain: CommunityThreadPage {
        CommunityThreadPage(
            pinned: pinned.map(\.toDomain),
            threads: threads.map(\.toDomain),
            nextOffset: nextOffset,
            total: total
        )
    }
}
