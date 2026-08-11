//
//  CommunityThreadDecodingTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
import CommunityDomain
@testable import CommunityData

@Suite("스레드 Response DTO 디코딩")
struct CommunityThreadDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("REST 응답의 String ID·수량을 그대로 String 으로 받는다")
    func decodesRestStringNumbers() throws {
        let json = """
        {
          "threadId": "12", "title": "iOS 스터디", "description": "매주 화요일",
          "category": "STUDY", "icon": "📚",
          "memberCount": "8", "unreadCount": "3", "maxMembers": "20",
          "isPinned": true, "isMuted": false, "isJoined": true, "myRole": "OWNER",
          "lastMessage": {"preview": "안녕", "senderName": "정의진",
                          "createdAt": "2026-08-11T10:00:00Z"},
          "createdBy": "5", "createdAt": "2026-08-01T00:00:00Z",
          "updatedAt": "2026-08-11T10:00:00Z"
        }
        """

        let thread = try decode(CommunityThreadDTO.self, json).toDomain

        #expect(thread.id == "12")
        #expect(thread.memberCount == "8")
        #expect(thread.unreadCount == "3")
        #expect(thread.category == .study)
        #expect(thread.myRole == .owner)
        #expect(thread.lastMessage?.senderName == "정의진")
        #expect(thread.unreadBadge == "3")
    }

    @Test("STOMP thread.invited 의 raw number ID·수량도 같은 DTO 로 받는다")
    func decodesRealtimeRawNumbers() throws {
        let json = """
        {
          "threadId": 12, "title": "iOS 스터디", "description": "",
          "category": "STUDY", "icon": "",
          "memberCount": 8, "unreadCount": 0, "maxMembers": 20,
          "isPinned": false, "isMuted": false, "isJoined": true, "myRole": "MEMBER",
          "lastMessage": null,
          "createdBy": 5, "createdAt": "2026-08-01T00:00:00Z",
          "updatedAt": "2026-08-11T10:00:00Z"
        }
        """

        let thread = try decode(CommunityThreadDTO.self, json).toDomain

        #expect(thread.id == "12")
        #expect(thread.memberCount == "8")
        #expect(thread.lastMessage == nil)
        // unreadCount 0 이면 배지를 숨긴다.
        #expect(thread.unreadBadge == nil)
        // icon 이 비면 카테고리 기본 이모지로 폴백한다.
        #expect(thread.displayIcon == "📚")
    }

    @Test("상세 응답의 shareUrl·deletedAt 을 함께 받는다")
    func decodesDetailFields() throws {
        let json = """
        {
          "threadId": "12", "title": "t", "description": "", "category": "FREE", "icon": "💬",
          "memberCount": "1", "unreadCount": "0", "maxMembers": "20",
          "isPinned": false, "isMuted": false, "isJoined": true, "myRole": "MEMBER",
          "lastMessage": null, "createdBy": "5",
          "createdAt": "2026-08-01T00:00:00Z", "updatedAt": "2026-08-01T00:00:00Z",
          "shareUrl": "https://umc.it.kr/t/12", "deletedAt": "2026-08-12T00:00:00Z"
        }
        """

        let thread = try decode(CommunityThreadDTO.self, json).toDomain

        #expect(thread.shareURL == "https://umc.it.kr/t/12")
        #expect(thread.deletedAt != nil)
    }

    @Test("검색 응답은 pinned 가 비어 있고 total 은 전체를 센다")
    func decodesSearchModeList() throws {
        let json = """
        {"pinned": [], "threads": [], "nextOffset": "20", "total": "37"}
        """

        let page = try decode(CommunityThreadListDTO.self, json).toDomain

        #expect(page.pinned.isEmpty)
        #expect(page.nextOffset == "20")
        #expect(page.total == "37")
    }

    @Test("마지막 페이지는 nextOffset 이 null 이다")
    func decodesLastPage() throws {
        let json = """
        {"pinned": [], "threads": [], "nextOffset": null, "total": "0"}
        """

        #expect(try decode(CommunityThreadListDTO.self, json).toDomain.nextOffset == nil)
    }

    @Test("알 수 없는 카테고리·역할은 폴백으로 흡수하고 던지지 않는다")
    func toleratesUnknownEnums() throws {
        let json = """
        {
          "threadId": "1", "title": "t", "description": "", "category": "NEWTHING", "icon": "",
          "memberCount": "1", "unreadCount": "0", "maxMembers": "20",
          "isPinned": false, "isMuted": false, "isJoined": false, "myRole": "GUEST",
          "lastMessage": null, "createdBy": "1",
          "createdAt": "2026-08-01T00:00:00Z", "updatedAt": "2026-08-01T00:00:00Z"
        }
        """

        let thread = try decode(CommunityThreadDTO.self, json).toDomain

        #expect(thread.category == .free)
        #expect(thread.myRole == nil)
    }

    @Test("수량 필드가 누락되거나 null 이어도 던지지 않고 0 으로 채운다")
    func defaultsMissingCountsToZero() throws {
        let missingKeys = """
        {
          "threadId": "1", "title": "t", "category": "STUDY",
          "createdAt": "2026-08-01T00:00:00Z", "updatedAt": "2026-08-01T00:00:00Z"
        }
        """
        let explicitNulls = """
        {
          "threadId": "1", "title": "t", "description": null, "category": "STUDY",
          "icon": null, "memberCount": null, "unreadCount": null, "maxMembers": null,
          "isPinned": null, "isMuted": null, "isJoined": null, "myRole": null,
          "lastMessage": null, "createdBy": null,
          "createdAt": "2026-08-01T00:00:00Z", "updatedAt": "2026-08-01T00:00:00Z"
        }
        """

        for json in [missingKeys, explicitNulls] {
            let thread = try decode(CommunityThreadDTO.self, json).toDomain

            #expect(thread.memberCount == "0")
            #expect(thread.unreadCount == "0")
            #expect(thread.maxMembers == "0")
            #expect(thread.unreadBadge == nil)
            #expect(thread.isPinned == false)
            #expect(thread.myRole == nil)
        }

        let listJSON = """
        {"threads": []}
        """
        let page = try decode(CommunityThreadListDTO.self, listJSON).toDomain

        #expect(page.total == "0")
        #expect(page.nextOffset == nil)
        #expect(page.pinned.isEmpty)
    }
}
