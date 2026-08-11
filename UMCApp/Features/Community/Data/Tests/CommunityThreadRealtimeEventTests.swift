//
//  CommunityThreadRealtimeEventTests.swift
//  CommunityDataTests
//

import Foundation
import Testing

import CommunityDomain

@Suite("커뮤니티 실시간 이벤트")
struct CommunityThreadRealtimeEventTests {

    // MARK: - Function

    /// 봉투(envelope)의 `threadId` 가 우선한다는 계약을 고정하려고 페이로드 안에는
    /// 일부러 다른 스레드 식별자를 넣는다.
    private func makeMessage(threadId: String = "payload-thread") -> ThreadMessage {
        ThreadMessage(
            id: "message-id",
            threadId: threadId,
            senderId: "sender-id",
            senderName: "정의진",
            content: "안녕하세요",
            type: .text,
            createdAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func makeThread(id: String) -> CommunityThread {
        CommunityThread(
            id: id,
            title: "iOS 스터디",
            description: "설명",
            category: .study,
            icon: "🔥",
            memberCount: "12",
            unreadCount: "0",
            maxMembers: "30",
            isPinned: false,
            isMuted: false,
            isJoined: true,
            myRole: .member,
            lastMessage: nil,
            createdBy: "creator-id",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func makeMetadataUpdate(threadId: String) -> ThreadMetadataUpdate {
        ThreadMetadataUpdate(
            threadId: threadId,
            title: "iOS 스터디",
            description: "설명",
            category: .project,
            icon: "🚀",
            memberCount: "13",
            maxMembers: "30",
            updatedAt: Date(timeIntervalSince1970: 200)
        )
    }

    private func makeCommandError(status: String) -> RealtimeCommandError {
        RealtimeCommandError(
            commandId: "command-id",
            clientMessageId: "client-id",
            status: status,
            code: "RATE_LIMITED",
            message: "요청이 너무 많습니다",
            retryable: true
        )
    }

    // MARK: - Message Event

    @Test("메시지 계열 이벤트의 threadId 는 봉투의 스레드 식별자다")
    func threadIdForMessageEvents() {
        let acknowledged = CommunityThreadRealtimeEvent.commandAcknowledged(
            threadId: "thread-ack",
            commandId: "command-id",
            messageId: "message-id",
            clientMessageId: "client-id",
            deduplicated: true
        )
        let created = CommunityThreadRealtimeEvent.messageCreated(
            threadId: "thread-created",
            message: makeMessage(),
            clientMessageId: "client-id"
        )
        let updated = CommunityThreadRealtimeEvent.messageUpdated(
            threadId: "thread-updated",
            message: makeMessage()
        )
        let deleted = CommunityThreadRealtimeEvent.messageDeleted(
            threadId: "thread-deleted",
            message: makeMessage()
        )

        #expect(acknowledged.threadId == "thread-ack")
        #expect(created.threadId == "thread-created")
        #expect(updated.threadId == "thread-updated")
        #expect(deleted.threadId == "thread-deleted")
    }

    @Test("리액션·읽음 이벤트의 threadId 는 메시지·멤버 식별자와 섞이지 않는다")
    func threadIdForReactionAndReadEvents() {
        let reaction = CommunityThreadRealtimeEvent.reactionChanged(
            threadId: "thread-reaction",
            messageId: "message-id",
            reactions: [ThreadMessageReaction(emoji: "👍", count: "2", reactedByMe: true)]
        )
        let read = CommunityThreadRealtimeEvent.readUpdated(
            threadId: "thread-read",
            memberId: "member-id",
            lastReadMessageId: "message-id"
        )

        #expect(reaction.threadId == "thread-reaction")
        #expect(read.threadId == "thread-read")
    }

    // MARK: - Thread Event

    @Test("스레드 계열 이벤트의 threadId 는 페이로드 안에서 꺼낸다")
    func threadIdForThreadEvents() {
        let invited = CommunityThreadRealtimeEvent.threadInvited(
            thread: makeThread(id: "thread-invited")
        )
        let updated = CommunityThreadRealtimeEvent.threadUpdated(
            update: makeMetadataUpdate(threadId: "thread-meta")
        )
        let deleted = CommunityThreadRealtimeEvent.threadDeleted(
            threadId: "thread-removed",
            deletedAt: Date(timeIntervalSince1970: 300)
        )

        #expect(invited.threadId == "thread-invited")
        #expect(updated.threadId == "thread-meta")
        #expect(deleted.threadId == "thread-removed")
    }

    @Test("멤버 이벤트의 threadId 는 멤버 식별자·인원수와 섞이지 않는다")
    func threadIdForMemberEvents() {
        let kicked = CommunityThreadRealtimeEvent.memberKicked(
            threadId: "thread-kicked",
            memberId: "member-id",
            memberCount: "11"
        )
        let left = CommunityThreadRealtimeEvent.memberLeft(
            threadId: "thread-left",
            memberId: "member-id",
            memberCount: "10"
        )

        #expect(kicked.threadId == "thread-kicked")
        #expect(left.threadId == "thread-left")
    }

    @Test("알 수 없는 타입도 threadId 로 필터링할 수 있다")
    func threadIdForUnknownEvent() {
        let unknown = CommunityThreadRealtimeEvent.unknown(
            type: "thread.archived",
            threadId: "thread-unknown"
        )

        #expect(unknown.threadId == "thread-unknown")
    }

    // MARK: - Command Error

    @Test("isRateLimited 는 status 가 정확히 429 일 때만 참이다")
    func rateLimitedOnlyForStatus429() {
        #expect(makeCommandError(status: "429").isRateLimited)
        #expect(makeCommandError(status: "400").isRateLimited == false)
        #expect(makeCommandError(status: "4290").isRateLimited == false)
        #expect(makeCommandError(status: "").isRateLimited == false)
    }

    @Test("커맨드 실패는 던져서 원래 타입으로 다시 잡을 수 있다")
    func commandErrorIsThrowable() throws {
        let thrown = #expect(throws: RealtimeCommandError.self) {
            throw self.makeCommandError(status: "429")
        }

        #expect(try #require(thrown).code == "RATE_LIMITED")
    }
}
