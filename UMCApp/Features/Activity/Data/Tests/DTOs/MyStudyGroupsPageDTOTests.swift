//
//  MyStudyGroupsPageDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Testing
import ActivityDomain
@testable import ActivityData

// MARK: - Helpers

private func decodePage(_ json: String) throws -> MyStudyGroupsPageDTO {
    try JSONDecoder().decode(MyStudyGroupsPageDTO.self, from: Data(json.utf8))
}

/// 단일 스터디 그룹 상세 JSON (페이지 항목용). part/createdAt 고정.
private func makeGroupJSON(groupId: String = "\"10\"", name: String = "\"iOS 1팀\"") -> String {
    """
    {
        "groupId": \(groupId),
        "name": \(name),
        "part": "IOS",
        "createdAt": "2026-05-11T09:30:00Z",
        "memberCount": 1,
        "schools": [],
        "mentors": [ { "challengerId": "1", "memberId": "1", "name": "재원" } ],
        "members": []
    }
    """
}

@Suite("MyStudyGroupsPageDTO — 디코딩/매핑")
struct MyStudyGroupsPageDTOTests {

    // MARK: - cursor 래핑 포맷

    @Test("cursor 래핑 포맷 — content/nextCursor/hasNext 를 디코딩한다")
    func decodesCursorWrappedFormat() throws {
        let json = """
        {
            "cursor": {
                "content": [\(makeGroupJSON())],
                "nextCursor": "cursor-2",
                "hasNext": true
            }
        }
        """
        let dto = try decodePage(json)

        #expect(dto.studyGroups.count == 1)
        #expect(dto.studyGroups.first?.groupId == "10")
        #expect(dto.nextCursor == "cursor-2")
        #expect(dto.hasNext == true)
    }

    @Test("cursor 래핑 포맷 — nextCursor 가 숫자로 와도 String 으로 디코딩한다")
    func decodesCursorWrappedNumericCursor() throws {
        let json = """
        { "cursor": { "content": [], "nextCursor": 42, "hasNext": false } }
        """
        let dto = try decodePage(json)

        #expect(dto.nextCursor == "42")
        #expect(dto.hasNext == false)
    }

    // MARK: - content 키 직접 포함 (flat) 포맷

    @Test("flat content 포맷 — content/nextCursor/hasNext 를 디코딩한다")
    func decodesFlatContentFormat() throws {
        let json = """
        {
            "content": [\(makeGroupJSON()), \(makeGroupJSON(groupId: "\"11\"", name: "\"iOS 2팀\""))],
            "nextCursor": "next-1",
            "hasNext": true
        }
        """
        let dto = try decodePage(json)

        #expect(dto.studyGroups.count == 2)
        #expect(dto.nextCursor == "next-1")
        #expect(dto.hasNext == true)
    }

    @Test("flat content 포맷 — hasNext 가 String 으로 와도 Bool 로 디코딩한다")
    func decodesFlatContentStringHasNext() throws {
        let json = """
        { "content": [\(makeGroupJSON())], "nextCursor": null, "hasNext": "true" }
        """
        let dto = try decodePage(json)

        #expect(dto.nextCursor == nil)
        #expect(dto.hasNext == true)
    }

    // MARK: - studyGroups 키 직접 포함 (최종 fallback) 포맷

    @Test("studyGroups 직접 포맷 — studyGroups/nextCursor/hasNext 를 디코딩한다")
    func decodesDirectStudyGroupsFormat() throws {
        let json = """
        {
            "studyGroups": [\(makeGroupJSON())],
            "nextCursor": "tail",
            "hasNext": false
        }
        """
        let dto = try decodePage(json)

        #expect(dto.studyGroups.count == 1)
        #expect(dto.nextCursor == "tail")
        #expect(dto.hasNext == false)
    }

    @Test("인식 가능한 키가 없으면 빈 목록 + 기본값으로 디코딩한다")
    func decodesEmptyWhenNoRecognizedKeys() throws {
        let dto = try decodePage("{}")

        #expect(dto.studyGroups.isEmpty)
        #expect(dto.nextCursor == nil)
        #expect(dto.hasNext == false)
    }

    @Test("studyGroups 직접 포맷 — 빈 배열을 빈 목록으로 디코딩한다")
    func decodesEmptyStudyGroupsArray() throws {
        let dto = try decodePage(#"{ "studyGroups": [], "hasNext": false }"#)
        #expect(dto.studyGroups.isEmpty)
    }

    // MARK: - Encodable round-trip

    @Test("custom encode 후 다시 디코딩하면 동일한 DTO 가 복원된다")
    func encodeRoundTrip() throws {
        let original = try decodePage("""
        {
            "studyGroups": [\(makeGroupJSON())],
            "nextCursor": "tail",
            "hasNext": true
        }
        """)
        let restored = try JSONDecoder().decode(
            MyStudyGroupsPageDTO.self,
            from: JSONEncoder().encode(original)
        )
        #expect(restored == original)
    }

    // MARK: - toDomain

    @Test("toDomain — content/hasNext/nextCursor 를 도메인 페이지로 매핑한다")
    func toDomainMapsPage() throws {
        let json = """
        {
            "cursor": {
                "content": [\(makeGroupJSON())],
                "nextCursor": "cursor-2",
                "hasNext": true
            }
        }
        """
        let page = try decodePage(json).toDomain()

        #expect(page.content.count == 1)
        #expect(page.content.first?.serverID == "10")
        #expect(page.content.first?.name == "iOS 1팀")
        #expect(page.content.first?.part == .front(type: .ios))
        #expect(page.hasNext == true)
        #expect(page.nextCursor == "cursor-2")
    }

    @Test("toDomain — 빈 페이지는 빈 content 와 nil cursor 로 매핑된다")
    func toDomainMapsEmptyPage() throws {
        let page = try decodePage("{}").toDomain()

        #expect(page.content.isEmpty)
        #expect(page.hasNext == false)
        #expect(page.nextCursor == nil)
    }
}
