//
//  CommunityThread.swift
//  CommunityDomain
//

import Foundation

public struct ThreadLastMessage: Hashable, Sendable {

    // MARK: - Property

    public let preview: String
    public let senderName: String
    public let createdAt: Date

    // MARK: - Init

    public init(preview: String, senderName: String, createdAt: Date) {
        self.preview = preview
        self.senderName = senderName
        self.createdAt = createdAt
    }
}

/// 리스트 행과 채팅방 헤더가 함께 쓰는 스레드 모델.
///
/// 상세 전용 필드(`shareURL`, `deletedAt`)는 요약 응답에서 `nil` 이다. 두 타입으로 쪼개면
/// 리스트 → 채팅방 전환에서 변환 코드만 늘어나 하나로 둔다.
public struct CommunityThread: Identifiable, Hashable, Sendable {

    // MARK: - Property

    public let id: String
    /// 아래 9개는 실시간 이벤트(`thread.updated`/`message.created`/`read.updated`/
    /// `member.left`)와 낙관적 토글이 제자리에서 갱신하므로 `var` 다. 나머지는 한 번 받으면
    /// 바뀌지 않아 `let` 으로 잠가 둔다.
    public var title: String
    public var description: String
    public var category: CommunityThreadCategory
    public var icon: String
    public var memberCount: String
    public var unreadCount: String
    public var isPinned: Bool
    public var isMuted: Bool
    public var lastMessage: ThreadLastMessage?
    public let maxMembers: String
    public let isJoined: Bool
    public let myRole: ThreadMemberRole?
    public let createdBy: String
    public let createdAt: Date
    public let updatedAt: Date
    public let shareURL: String?
    public let deletedAt: Date?

    // MARK: - Init

    public init(
        id: String,
        title: String,
        description: String,
        category: CommunityThreadCategory,
        icon: String,
        memberCount: String,
        unreadCount: String,
        maxMembers: String,
        isPinned: Bool,
        isMuted: Bool,
        isJoined: Bool,
        myRole: ThreadMemberRole?,
        lastMessage: ThreadLastMessage?,
        createdBy: String,
        createdAt: Date,
        updatedAt: Date,
        shareURL: String? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
        self.memberCount = memberCount
        self.unreadCount = unreadCount
        self.maxMembers = maxMembers
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isJoined = isJoined
        self.myRole = myRole
        self.lastMessage = lastMessage
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.shareURL = shareURL
        self.deletedAt = deletedAt
    }

    // MARK: - Computed Property

    /// 서버 `icon` 이 비어 오면 카테고리 기본 이모지로 폴백한다.
    public var displayIcon: String {
        icon.isEmpty ? category.defaultIcon : icon
    }

    /// 배지에 찍을 문자열. 0 이면 배지를 숨기고, 99 를 넘으면 `99+`.
    public var unreadBadge: String? {
        guard let count = Int(unreadCount), count > 0 else { return nil }
        return count > 99 ? "99+" : String(count)
    }

    /// 읽지 않은 메시지가 남았는지. 리스트 행의 강조(볼드·틴트)와 딤을 가르는 기준이다.
    public var isUnread: Bool {
        unreadBadge != nil
    }

    public var memberCountText: String {
        "멤버 \(memberCount)명"
    }

    /// 이 스레드를 수정·삭제할 수 있는지.
    ///
    /// 서버는 `OWNER` 와 `ADMIN` 둘 다 허용한다(위반 시 403 `COMMUNITY-0040`). 시안이
    /// "개설자 전용" 이라 적었지만 그대로 좁히면 위임으로 `ADMIN` 이 된 전 개설자가 자기가 만든
    /// 스레드를 못 고친다 — 게이팅 기준은 서버 규칙에 맞춘다.
    public var canEdit: Bool {
        myRole == .owner || myRole == .admin
    }

    // MARK: - Function

    /// 낙관적 토글용 복사본. 실패하면 이전 값으로 되돌린다.
    public func with(isPinned: Bool? = nil, isMuted: Bool? = nil) -> CommunityThread {
        var copy = self
        if let isPinned { copy.isPinned = isPinned }
        if let isMuted { copy.isMuted = isMuted }
        return copy
    }
}

/// `GET /threads` 한 페이지.
///
/// - Important: `q` 가 없으면 `pinned` 는 페이징되지 않고 `total`/`nextOffset` 은 `threads` 만 센다.
///   `q` 가 있으면 `pinned` 는 항상 비고 모든 매칭이 `threads` 에 들어간다.
public struct CommunityThreadPage: Equatable, Sendable {

    // MARK: - Property

    public let pinned: [CommunityThread]
    public let threads: [CommunityThread]
    public let nextOffset: String?
    public let total: String

    // MARK: - Init

    public init(
        pinned: [CommunityThread],
        threads: [CommunityThread],
        nextOffset: String?,
        total: String
    ) {
        self.pinned = pinned
        self.threads = threads
        self.nextOffset = nextOffset
        self.total = total
    }
}
