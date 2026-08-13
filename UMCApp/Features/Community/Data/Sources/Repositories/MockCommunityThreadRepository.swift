//
//  MockCommunityThreadRepository.swift
//  CommunityData
//

#if DEBUG
import Foundation
import CommunityDomain

/// 네트워크 없이 리스트·채팅방 UI 를 돌려 보기 위한 Mock.
///
/// 릴리스 빌드에는 포함되지 않는다(절대 규칙 #5).
public struct MockCommunityThreadRepository: CommunityThreadRepositoryProtocol {

    // MARK: - Init

    public init() {}

    // MARK: - Function

    public func fetchThreads(
        filter: String,
        query: String?,
        offset: Int,
        limit: Int
    ) async throws -> CommunityThreadPage {
        // 검색 모드에서는 서버가 pinned 를 비우고 고정 스레드를 threads 위로 올린다.
        guard query == nil else {
            return CommunityThreadPage(
                pinned: [],
                threads: [Self.pinnedSample, Self.plainSample],
                nextOffset: nil,
                total: "2"
            )
        }
        return CommunityThreadPage(
            pinned: [Self.pinnedSample],
            threads: [Self.plainSample],
            nextOffset: nil,
            total: "1"
        )
    }

    public func fetchThread(threadId: String) async throws -> CommunityThread {
        Self.pinnedSample
    }

    /// 서버처럼 개설자를 `OWNER` 로 넣은 새 스레드를 돌려준다.
    public func createThread(
        title: String,
        description: String,
        category: String,
        icon: String
    ) async throws -> CommunityThread {
        CommunityThread(
            id: "999",
            title: title,
            description: description,
            category: CommunityThreadCategory(rawValue: category) ?? .free,
            icon: icon,
            memberCount: "1",
            unreadCount: "0",
            maxMembers: "100",
            isPinned: false,
            isMuted: false,
            isJoined: true,
            myRole: .owner,
            lastMessage: nil,
            createdBy: "5",
            createdAt: Self.referenceDate,
            updatedAt: Self.referenceDate
        )
    }

    /// 서버처럼 넘어온 필드만 갈아 끼운다 — `nil` 은 "안 바꾼다" 다.
    public func updateThread(
        threadId: String,
        title: String?,
        description: String?,
        category: String?,
        icon: String?
    ) async throws -> CommunityThread {
        var thread = Self.pinnedSample
        if let title { thread.title = title }
        if let description { thread.description = description }
        if let category { thread.category = CommunityThreadCategory(rawValue: category) ?? .free }
        if let icon { thread.icon = icon }
        return thread
    }

    public func deleteThread(threadId: String) async throws {}

    public func fetchMessages(
        threadId: String,
        before: String?,
        limit: Int
    ) async throws -> ThreadMessagePage {
        // 서버와 같이 최신순으로 준다.
        ThreadMessagePage(
            messages: [
                Self.message(id: "3", sender: "정의진", content: "네 좋아요"),
                Self.message(id: "2", sender: "이재원", content: "화요일 8시 어때요?"),
                Self.message(id: "1", sender: "정의진", content: "이번 주 스터디 언제 하죠?")
            ],
            hasMore: false,
            nextBefore: nil
        )
    }

    public func setPinned(threadId: String, isPinned: Bool) async throws {}
    public func setMuted(threadId: String, isMuted: Bool) async throws {}

    public func fetchMembers(threadId: String) async throws -> [ThreadMember] {
        Self.memberSamples
    }

    public func kickMember(threadId: String, memberId: String) async throws {}
    public func changeMemberRole(threadId: String, memberId: String, role: String) async throws {}
    public func leaveThread(threadId: String) async throws {}
    public func reportMessage(messageId: String, reason: String) async throws {}

    // MARK: - Sample

    private static let referenceDate = Date(timeIntervalSince1970: 1_786_000_000)

    private static let pinnedSample = CommunityThread(
        id: "1",
        title: "iOS 스터디",
        description: "매주 화요일 8시",
        category: .study,
        icon: "📚",
        memberCount: "8",
        unreadCount: "3",
        maxMembers: "20",
        isPinned: true,
        isMuted: false,
        isJoined: true,
        myRole: .owner,
        lastMessage: ThreadLastMessage(
            preview: "네 좋아요",
            senderName: "정의진",
            createdAt: referenceDate
        ),
        createdBy: "5",
        createdAt: referenceDate,
        updatedAt: referenceDate
    )

    private static let plainSample = CommunityThread(
        id: "2",
        title: "자유로운 잡담방",
        description: "",
        category: .free,
        icon: "",
        memberCount: "42",
        unreadCount: "0",
        maxMembers: "100",
        isPinned: false,
        isMuted: true,
        isJoined: false,
        myRole: nil,
        lastMessage: nil,
        createdBy: "9",
        createdAt: referenceDate,
        updatedAt: referenceDate
    )

    /// 개설자(나)·참여자 두 명. 위임·내보내기 메뉴가 둘 다 나오는 최소 구성이다.
    private static let memberSamples = [
        ThreadMember(
            id: "5",
            name: "정의진",
            part: "iOS",
            profileImageURL: nil,
            role: .owner
        ),
        ThreadMember(
            id: "9",
            name: "이재원",
            part: "Spring",
            profileImageURL: nil,
            role: .member
        )
    ]

    private static func message(id: String, sender: String, content: String) -> ThreadMessage {
        ThreadMessage(
            id: id,
            threadId: "1",
            senderId: sender == "정의진" ? "5" : "9",
            senderName: sender,
            content: content,
            type: .text,
            createdAt: referenceDate
        )
    }
}
#endif
