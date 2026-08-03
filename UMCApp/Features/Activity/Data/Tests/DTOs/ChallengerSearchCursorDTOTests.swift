//
//  ChallengerSearchCursorDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 8/3/26.
//

import Testing
import Foundation
import UMCFoundation
@testable import ActivityData

// MARK: - Suite: 챌린저 커서 검색 디코딩 계약

@Suite("ChallengerSearchCursorDTO — 디코딩 매핑 (서버 contract)")
struct ChallengerSearchCursorDTODecodingTests {

    private func decode(_ json: String) throws -> ChallengerSearchCursorResultDTO {
        try JSONDecoder().decode(
            ChallengerSearchCursorResultDTO.self,
            from: Data(json.utf8)
        )
    }

    @Test("cursor 래퍼의 content·nextCursor·hasNext 를 매핑한다")
    func decodesCursorEnvelope() throws {
        let json = """
        {
          "cursor": {
            "content": [
              {
                "challengerId": 7, "memberId": 100, "gisuId": 70,
                "generation": 9, "gisu": 9, "part": "IOS", "name": "홍길동",
                "nickname": "길동", "schoolName": "한성대", "pointSum": 3,
                "profileImageLink": "https://img/1.png",
                "roleTypes": ["CHALLENGER"]
              }
            ],
            "nextCursor": 12,
            "hasNext": true
          },
          "partCounts": [{ "part": "IOS", "count": 1 }]
        }
        """

        let result = try decode(json)
        let item = try #require(result.cursor.content.first)

        #expect(result.cursor.nextCursor == 12)
        #expect(result.cursor.hasNext)
        #expect(item.challengerId == "7")
        #expect(item.memberId == "100")
        #expect(item.gisu == 9)
        #expect(item.profileImageURL == "https://img/1.png")
    }

    @Test("nextCursor 를 문자열로 내려줘도 Int 로 해석한다")
    func decodesStringNextCursorAsInt() throws {
        let json = """
        { "cursor": { "content": [], "nextCursor": "31", "hasNext": true } }
        """

        let result = try decode(json)

        #expect(result.cursor.nextCursor == 31)
    }

    @Test("마지막 페이지는 nextCursor 가 null, hasNext 가 false 다")
    func decodesLastPage() throws {
        let json = """
        { "cursor": { "content": [], "nextCursor": null, "hasNext": false } }
        """

        let result = try decode(json)

        #expect(result.cursor.nextCursor == nil)
        #expect(result.cursor.hasNext == false)
    }

    @Test("cursor 필드가 없으면 빈 페이지로 폴백한다")
    func missingCursorFallsBackToEmpty() throws {
        let result = try decode("{}")

        #expect(result.cursor.content.isEmpty)
        #expect(result.cursor.nextCursor == nil)
        #expect(result.cursor.hasNext == false)
    }
}
