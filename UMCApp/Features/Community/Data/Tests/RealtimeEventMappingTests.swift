//
//  RealtimeEventMappingTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
import CommunityDomain
@testable import CommunityData

@Suite("STOMP envelope → 도메인 이벤트 매핑")
struct RealtimeEventMappingTests {

    private func event(_ json: String) throws -> CommunityThreadRealtimeEvent {
        try JSONDecoder().decode(RealtimeEnvelopeDTO.self, from: Data(json.utf8)).event
    }

    @Test("message.created 는 메시지와 clientMessageId 를 함께 싣는다")
    func mapsMessageCreated() throws {
        let json = """
        {
          "eventId": "e-1", "type": "message.created", "threadId": "12",
          "occurredAt": "2026-08-11T10:00:00Z",
          "payload": {
            "message": {
              "messageId": 1024, "threadId": 12, "senderId": 5, "senderName": "정의진",
              "content": "안녕", "type": "TEXT", "status": "SENT",
              "files": [], "mentions": [], "reactions": [],
              "createdAt": "2026-08-11T10:00:00Z"
            },
            "clientMessageId": "aaaa-bbbb"
          }
        }
        """

        guard case .messageCreated(let threadId, let message, let clientMessageId)
            = try event(json) else {
            Issue.record("messageCreated 가 아니다")
            return
        }
        #expect(threadId == "12")
        #expect(message.id == "1024")
        #expect(clientMessageId == "aaaa-bbbb")
    }

    @Test("clientMessageId 가 message 안에만 있어도 읽어 낸다")
    func readsClientMessageIdFromNestedMessage() throws {
        let json = """
        {
          "eventId": "e-2", "type": "message.created", "threadId": "12",
          "occurredAt": "2026-08-11T10:00:00Z",
          "payload": {
            "message": {
              "messageId": 1025, "threadId": 12, "senderId": 5, "senderName": "정의진",
              "content": "안녕", "type": "TEXT", "status": "SENT",
              "files": [], "mentions": [], "reactions": [],
              "clientMessageId": "nested-id",
              "createdAt": "2026-08-11T10:00:00Z"
            }
          }
        }
        """

        guard case .messageCreated(_, _, let clientMessageId) = try event(json) else {
            Issue.record("messageCreated 가 아니다")
            return
        }
        #expect(clientMessageId == "nested-id")
    }

    @Test("read.updated 의 raw number 필드를 String 으로 받는다")
    func mapsReadUpdated() throws {
        let json = """
        {
          "eventId": "e-3", "type": "read.updated", "threadId": "12",
          "occurredAt": "2026-08-11T10:00:00Z",
          "payload": {"memberId": 5, "lastReadMessageId": 1024}
        }
        """

        guard case .readUpdated(let threadId, let memberId, let lastReadMessageId)
            = try event(json) else {
            Issue.record("readUpdated 가 아니다")
            return
        }
        #expect(threadId == "12")
        #expect(memberId == "5")
        #expect(lastReadMessageId == "1024")
    }

    @Test("thread.updated 는 부분 갱신이라 개인화 필드가 없다")
    func mapsThreadUpdated() throws {
        let json = """
        {
          "eventId": "e-4", "type": "thread.updated", "threadId": "12",
          "occurredAt": "2026-08-11T10:00:00Z",
          "payload": {
            "threadId": "12", "title": "새 제목", "description": "설명",
            "category": "PROJECT", "icon": "🚀",
            "memberCount": 9, "maxMembers": 20,
            "lastActivityAt": "2026-08-11T10:00:00Z", "updatedAt": "2026-08-11T10:00:00Z"
          }
        }
        """

        guard case .threadUpdated(let update) = try event(json) else {
            Issue.record("threadUpdated 가 아니다")
            return
        }
        #expect(update.title == "새 제목")
        #expect(update.category == .project)
        #expect(update.memberCount == "9")
    }

    @Test("member.left 는 남은 멤버 수를 함께 준다")
    func mapsMemberLeft() throws {
        let json = """
        {
          "eventId": "e-5", "type": "member.left", "threadId": "12",
          "occurredAt": "2026-08-11T10:00:00Z",
          "payload": {"memberId": 5, "memberCount": 7}
        }
        """

        guard case .memberLeft(_, let memberId, let memberCount) = try event(json) else {
            Issue.record("memberLeft 가 아니다")
            return
        }
        #expect(memberId == "5")
        #expect(memberCount == "7")
    }

    @Test("모르는 타입은 unknown 으로 흡수하고 던지지 않는다")
    func mapsUnknownType() throws {
        let json = """
        {
          "eventId": "e-6", "type": "poll.created", "threadId": "12",
          "occurredAt": "2026-08-11T10:00:00Z", "payload": {}
        }
        """

        guard case .unknown(let type, let threadId) = try event(json) else {
            Issue.record("unknown 이 아니다")
            return
        }
        #expect(type == "poll.created")
        #expect(threadId == "12")
    }

    @Test(
        "threadId 가 없거나 비면 매핑을 실패시킨다 — 빈 문자열로 흘려보내면 화면 필터에서 사라진다",
        arguments: [
            """
            {
              "eventId": "e-7", "type": "poll.created",
              "occurredAt": "2026-08-11T10:00:00Z", "payload": {}
            }
            """,
            """
            {
              "eventId": "e-8", "type": "poll.created", "threadId": "",
              "occurredAt": "2026-08-11T10:00:00Z", "payload": {}
            }
            """,
            """
            {
              "eventId": "e-9", "type": "read.updated",
              "occurredAt": "2026-08-11T10:00:00Z",
              "payload": {"memberId": 5, "lastReadMessageId": 1024}
            }
            """,
        ]
    )
    func rejectsEventWithoutThreadId(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RealtimeEnvelopeDTO.self, from: Data(json.utf8))
        }
    }

    @Test("thread.updated 는 봉투에 threadId 가 없어도 payload 로 라우팅한다")
    func fallsBackToPayloadThreadId() throws {
        let json = """
        {
          "eventId": "e-10", "type": "thread.updated",
          "occurredAt": "2026-08-11T10:00:00Z",
          "payload": {
            "threadId": 12, "title": "새 제목", "description": "설명",
            "category": "PROJECT", "icon": "🚀",
            "memberCount": 9, "maxMembers": 20, "updatedAt": "2026-08-11T10:00:00Z"
          }
        }
        """

        #expect(try event(json).threadId == "12")
    }

    @Test("에러 프레임을 RealtimeCommandError 로 매핑한다")
    func mapsErrorFrame() throws {
        let json = """
        {
          "commandId": "c-1", "clientMessageId": "aaaa-bbbb", "status": 429,
          "code": "RATE_LIMITED", "message": "너무 빠릅니다", "retryable": true
        }
        """

        let error = try JSONDecoder()
            .decode(RealtimeErrorDTO.self, from: Data(json.utf8)).toDomain

        #expect(error.clientMessageId == "aaaa-bbbb")
        #expect(error.status == "429")
        #expect(error.isRateLimited)
        #expect(error.retryable)
    }
}

@Suite("EventDeduplicator — eventId 중복 제거")
struct EventDeduplicatorTests {

    @Test("같은 eventId 는 한 번만 통과한다")
    func dropsDuplicate() {
        var deduplicator = EventDeduplicator()
        // #expect 는 인자를 immutable 클로저로 감싸므로 mutating 호출은 밖에서 끝낸다.
        let accepted = ["e-1", "e-1", "e-2"].map { deduplicator.shouldProcess($0) }

        #expect(accepted == [true, false, true])
    }

    @Test("용량을 넘으면 가장 오래된 id 부터 잊는다 — 무한히 쌓이지 않는다")
    func evictsOldestBeyondCapacity() {
        var deduplicator = EventDeduplicator(capacity: 2)
        let accepted = ["e-1", "e-2", "e-3", "e-1", "e-3"].map { deduplicator.shouldProcess($0) }

        // e-1 은 용량에서 밀려나 다시 통과하고, e-3 은 아직 기억한다.
        #expect(accepted == [true, true, true, true, false])
    }
}
