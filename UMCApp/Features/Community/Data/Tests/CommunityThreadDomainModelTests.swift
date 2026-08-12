//
//  CommunityThreadDomainModelTests.swift
//  CommunityDataTests
//

import Foundation
import Testing

import CommunityDomain

@Suite("커뮤니티 스레드 도메인 모델")
struct CommunityThreadDomainModelTests {

    // MARK: - Function

    private func makeThread(
        icon: String = "🔥",
        category: CommunityThreadCategory = .study,
        memberCount: String = "12",
        unreadCount: String = "0",
        isPinned: Bool = false,
        isMuted: Bool = false
    ) -> CommunityThread {
        CommunityThread(
            id: "1",
            title: "iOS 스터디",
            description: "설명",
            category: category,
            icon: icon,
            memberCount: memberCount,
            unreadCount: unreadCount,
            maxMembers: "30",
            isPinned: isPinned,
            isMuted: isMuted,
            isJoined: true,
            myRole: .member,
            lastMessage: nil,
            createdBy: "9",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func makeMessage(
        editedAt: Date? = nil,
        deletedAt: Date? = nil,
        deliveryState: ThreadMessageDeliveryState = .sent
    ) -> ThreadMessage {
        ThreadMessage(
            id: "10",
            threadId: "1",
            senderId: "9",
            senderName: "정의진",
            content: "안녕하세요",
            type: .text,
            files: [
                ThreadMessageFile(
                    id: "f1",
                    fileName: "spec.pdf",
                    fileSize: "1024",
                    fileURL: "https://cdn.umc.dev/spec.pdf?token=a"
                )
            ],
            mentions: [ThreadMessageMention(memberId: "3", name: "김운영")],
            replyTo: ThreadMessageReply(messageId: "9", senderName: "김운영", snippet: "확인"),
            reactions: [ThreadMessageReaction(emoji: "👍", count: "2", reactedByMe: true)],
            clientMessageId: "client-1",
            createdAt: Date(timeIntervalSince1970: 200),
            editedAt: editedAt,
            deletedAt: deletedAt,
            deliveryState: deliveryState
        )
    }

    // MARK: - Enum

    @Test("카테고리 rawValue 는 서버 enum 과 1:1 이다")
    func categoryRawValues() {
        #expect(CommunityThreadCategory.study.rawValue == "STUDY")
        #expect(CommunityThreadCategory.qna.rawValue == "QNA")
        #expect(CommunityThreadCategory.project.rawValue == "PROJECT")
        #expect(CommunityThreadCategory.free.rawValue == "FREE")
        #expect(CommunityThreadCategory(rawValue: "STUDY") == .study)
        #expect(CommunityThreadCategory(rawValue: "study") == nil)
    }

    @Test("역할·메시지 타입 rawValue 는 대문자 서버 값이다")
    func roleAndMessageTypeRawValues() {
        #expect(ThreadMemberRole.owner.rawValue == "OWNER")
        #expect(ThreadMemberRole.admin.rawValue == "ADMIN")
        #expect(ThreadMemberRole.member.rawValue == "MEMBER")
        #expect(ThreadMessageType.text.rawValue == "TEXT")
        #expect(ThreadMessageType.image.rawValue == "IMAGE")
        #expect(ThreadMessageType.system.rawValue == "SYSTEM")
    }

    @Test("필터 queryValue 는 all/unread 소문자, 카테고리는 서버 rawValue 다")
    func filterQueryValue() {
        #expect(CommunityThreadFilter.all.queryValue == "all")
        #expect(CommunityThreadFilter.unread.queryValue == "unread")
        #expect(CommunityThreadFilter.category(.qna).queryValue == "QNA")
        #expect(CommunityThreadFilter.category(.free).displayName == "자유")
    }

    @Test("필터 메뉴는 전체·안읽음 뒤에 카테고리 선언 순서로 이어진다")
    func filterMenuItemsOrder() {
        let queryValues = CommunityThreadFilter.menuItems.map(\.queryValue)

        #expect(queryValues == ["all", "unread", "STUDY", "QNA", "PROJECT", "FREE"])
    }

    // MARK: - Thread

    @Test("icon 이 비면 카테고리 기본 이모지로 폴백한다")
    func displayIconFallsBackToCategoryDefault() {
        #expect(makeThread(icon: "🔥").displayIcon == "🔥")
        #expect(makeThread(icon: "", category: .study).displayIcon == "📚")
        #expect(makeThread(icon: "", category: .qna).displayIcon == "❓")
        #expect(makeThread(icon: "", category: .project).displayIcon == "🚀")
        #expect(makeThread(icon: "", category: .free).displayIcon == "💬")
    }

    @Test("unreadBadge 는 0 이면 숨기고 99 를 넘으면 99+ 로 자른다")
    func unreadBadgeThresholds() {
        #expect(makeThread(unreadCount: "0").unreadBadge == nil)
        #expect(makeThread(unreadCount: "1").unreadBadge == "1")
        #expect(makeThread(unreadCount: "99").unreadBadge == "99")
        #expect(makeThread(unreadCount: "100").unreadBadge == "99+")
        #expect(makeThread(unreadCount: "").unreadBadge == nil)
    }

    @Test("memberCountText 는 멤버 수를 그대로 문장에 넣는다")
    func memberCountText() {
        #expect(makeThread(memberCount: "12").memberCountText == "멤버 12명")
    }

    @Test("with 는 전달한 토글만 바꾸고 나머지는 유지한다")
    func withTogglesOnlyGivenFlags() {
        let thread = makeThread(isPinned: false, isMuted: true)

        let pinned = thread.with(isPinned: true)
        #expect(pinned.isPinned)
        #expect(pinned.isMuted)
        #expect(pinned.id == thread.id)

        let unmuted = thread.with(isMuted: false)
        #expect(unmuted.isPinned == false)
        #expect(unmuted.isMuted == false)

        #expect(thread.with() == thread)
        #expect(thread.isPinned == false)
    }

    // MARK: - Message

    @Test("isDeleted·isEdited 는 타임스탬프 유무로 판정한다")
    func messageTombstoneFlags() {
        let plain = makeMessage()
        #expect(plain.isDeleted == false)
        #expect(plain.isEdited == false)

        let edited = makeMessage(editedAt: Date(timeIntervalSince1970: 300))
        #expect(edited.isEdited)
        #expect(edited.isDeleted == false)

        let deleted = makeMessage(deletedAt: Date(timeIntervalSince1970: 400))
        #expect(deleted.isDeleted)
    }

    @Test("with(deliveryState:) 는 전송 상태만 바꾼다")
    func withDeliveryStateKeepsOtherFields() {
        let sending = makeMessage(deliveryState: .sending)
        let failed = sending.with(deliveryState: .failed)

        #expect(failed.deliveryState == .failed)
        #expect(sending.deliveryState == .sending)
        #expect(failed.content == sending.content)
        #expect(failed.clientMessageId == sending.clientMessageId)
        #expect(failed.reactions == sending.reactions)
        #expect(failed.files.map(\.id) == ["f1"])
    }

    @Test("메시지 기본 인자는 첨부 없는 전송 완료 상태다")
    func messageDefaultArguments() {
        let message = ThreadMessage(
            id: "11",
            threadId: "1",
            senderId: "9",
            senderName: "정의진",
            content: "hi",
            type: .text,
            createdAt: Date(timeIntervalSince1970: 500)
        )

        #expect(message.files.isEmpty)
        #expect(message.mentions.isEmpty)
        #expect(message.reactions.isEmpty)
        #expect(message.replyTo == nil)
        #expect(message.clientMessageId == nil)
        #expect(message.deliveryState == .sent)
    }
}
