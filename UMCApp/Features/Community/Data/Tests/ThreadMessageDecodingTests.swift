//
//  ThreadMessageDecodingTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
import CommunityDomain
@testable import CommunityData

@Suite("메시지 Response DTO 디코딩 — REST/STOMP 공용")
struct ThreadMessageDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("REST 메시지(String ID)를 디코딩한다")
    func decodesRestMessage() throws {
        let json = """
        {
          "messageId": "1024", "threadId": "12", "senderId": "5", "senderName": "정의진",
          "content": "안녕하세요", "type": "TEXT", "status": "SENT",
          "files": [], "mentions": [], "replyTo": null, "reactions": [],
          "createdAt": "2026-08-11T10:00:00Z", "editedAt": null, "deletedAt": null
        }
        """

        let message = try decode(ThreadMessageDTO.self, json).toDomain

        #expect(message.id == "1024")
        #expect(message.type == .text)
        #expect(message.deliveryState == .sent)
        #expect(message.isDeleted == false)
        #expect(message.clientMessageId == nil)
    }

    @Test("STOMP 메시지(raw number ID + clientMessageId)를 같은 DTO 로 디코딩한다")
    func decodesRealtimeMessage() throws {
        let json = """
        {
          "messageId": 1024, "threadId": 12, "senderId": 5, "senderName": "정의진",
          "content": "안녕하세요", "type": "TEXT", "status": "SENT",
          "files": [], "mentions": [], "replyTo": null, "reactions": [],
          "clientMessageId": "5f8b1c2e-1111-4222-8333-444455556666",
          "createdAt": "2026-08-11T10:00:00Z", "editedAt": null, "deletedAt": null
        }
        """

        let message = try decode(ThreadMessageDTO.self, json).toDomain

        #expect(message.id == "1024")
        #expect(message.threadId == "12")
        #expect(message.clientMessageId == "5f8b1c2e-1111-4222-8333-444455556666")
    }

    @Test("deletedAt 이 있으면 톰스톤으로 판정한다 — status 는 쓰지 않는다")
    func detectsTombstoneByDeletedAt() throws {
        let json = """
        {
          "messageId": "9", "threadId": "1", "senderId": "2", "senderName": "이재원",
          "content": "", "type": "TEXT", "status": "SENT",
          "files": [], "mentions": [], "reactions": [],
          "createdAt": "2026-08-11T10:00:00Z", "deletedAt": "2026-08-11T11:00:00Z"
        }
        """

        #expect(try decode(ThreadMessageDTO.self, json).toDomain.isDeleted)
    }

    @Test("첨부·멘션·답글·리액션 하위 구조를 모두 매핑한다")
    func decodesNestedStructures() throws {
        let json = """
        {
          "messageId": "9", "threadId": "1", "senderId": "2", "senderName": "이재원",
          "content": "사진", "type": "IMAGE", "status": "SENT",
          "files": [{"fileId": "f1", "fileName": "a.png", "fileSize": 2048,
                     "fileUrl": "https://cdn/x?sig=1"}],
          "mentions": [{"memberId": 7, "name": "정의진"}],
          "replyTo": {"messageId": 8, "senderName": "정의진", "snippet": "이전 메시지"},
          "reactions": [{"emoji": "👍", "count": 3, "reactedByMe": true}],
          "createdAt": "2026-08-11T10:00:00Z"
        }
        """

        let message = try decode(ThreadMessageDTO.self, json).toDomain

        #expect(message.type == .image)
        #expect(message.files.first?.id == "f1")
        #expect(message.files.first?.fileSize == "2048")
        #expect(message.mentions.first?.memberId == "7")
        #expect(message.replyTo?.messageId == "8")
        #expect(message.replyTo?.snippet == "이전 메시지")
        #expect(message.reactions.first?.count == "3")
        #expect(message.reactions.first?.reactedByMe == true)
    }

    @Test("하위 구조의 수량·ID 가 REST String 으로 와도 같은 값으로 받는다")
    func decodesNestedStructuresFromRestStrings() throws {
        let json = """
        {
          "messageId": "9", "threadId": "1", "senderId": "2", "senderName": "이재원",
          "content": "사진", "type": "IMAGE", "status": "SENT",
          "files": [{"fileId": "f1", "fileName": "a.png", "fileSize": "2048",
                     "fileUrl": "https://cdn/x?sig=1"}],
          "mentions": [{"memberId": "7", "name": "정의진"}],
          "replyTo": {"messageId": "8", "senderName": "정의진", "snippet": "이전 메시지"},
          "reactions": [{"emoji": "👍", "count": "3", "reactedByMe": true}],
          "createdAt": "2026-08-11T10:00:00Z"
        }
        """

        let message = try decode(ThreadMessageDTO.self, json).toDomain

        #expect(message.files.first?.fileSize == "2048")
        #expect(message.mentions.first?.memberId == "7")
        #expect(message.replyTo?.messageId == "8")
        #expect(message.reactions.first?.count == "3")
    }

    @Test("히스토리 페이지는 hasMore 와 배타적 커서 nextBefore 를 준다")
    func decodesPage() throws {
        let json = """
        {"messages": [], "hasMore": true, "nextBefore": "1000"}
        """

        let page = try decode(ThreadMessagePageDTO.self, json).toDomain

        #expect(page.hasMore)
        #expect(page.nextBefore == "1000")
    }

    @Test("마지막 페이지는 hasMore false, nextBefore null 이다")
    func decodesFinalPage() throws {
        let json = """
        {"messages": [], "hasMore": false, "nextBefore": null}
        """

        let page = try decode(ThreadMessagePageDTO.self, json).toDomain

        #expect(page.hasMore == false)
        #expect(page.nextBefore == nil)
    }

    @Test("알 수 없는 메시지 타입은 SYSTEM 으로 폴백한다")
    func toleratesUnknownType() throws {
        let json = """
        {
          "messageId": "1", "threadId": "1", "senderId": "1", "senderName": "s",
          "content": "", "type": "POLL", "status": "SENT",
          "files": [], "mentions": [], "reactions": [],
          "createdAt": "2026-08-11T10:00:00Z"
        }
        """

        #expect(try decode(ThreadMessageDTO.self, json).toDomain.type == .system)
    }

    @Test("수량·컬렉션이 누락되거나 null 이어도 던지지 않고 기본값으로 채운다")
    func defaultsMissingQuantitiesToZero() throws {
        let missingKeys = """
        {"messageId": "1", "createdAt": "2026-08-11T10:00:00Z"}
        """
        let explicitNulls = """
        {
          "messageId": "1", "threadId": null, "senderId": null, "senderName": null,
          "content": null, "type": null, "status": null,
          "files": null, "mentions": null, "replyTo": null, "reactions": null,
          "clientMessageId": null,
          "createdAt": "2026-08-11T10:00:00Z", "editedAt": null, "deletedAt": null
        }
        """

        for json in [missingKeys, explicitNulls] {
            let message = try decode(ThreadMessageDTO.self, json).toDomain

            #expect(message.files.isEmpty)
            #expect(message.mentions.isEmpty)
            #expect(message.reactions.isEmpty)
            #expect(message.replyTo == nil)
            #expect(message.clientMessageId == nil)
            #expect(message.type == .system)
            #expect(message.isDeleted == false)
        }

        let fileJSON = """
        {"fileId": "f1"}
        """
        #expect(try decode(ThreadMessageFileDTO.self, fileJSON).toDomain.fileSize == "0")

        let reactionJSON = """
        {"emoji": "👍", "count": null, "reactedByMe": null}
        """
        let reaction = try decode(ThreadMessageReactionDTO.self, reactionJSON).toDomain

        #expect(reaction.count == "0")
        #expect(reaction.reactedByMe == false)

        let pageJSON = """
        {}
        """
        let page = try decode(ThreadMessagePageDTO.self, pageJSON).toDomain

        #expect(page.messages.isEmpty)
        #expect(page.hasMore == false)
        #expect(page.nextBefore == nil)
    }
}
