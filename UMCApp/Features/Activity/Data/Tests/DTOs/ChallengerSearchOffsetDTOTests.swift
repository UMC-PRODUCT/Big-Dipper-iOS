//
//  ChallengerSearchOffsetDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/28/26.
//

import Testing
import Foundation
import UMCFoundation
@testable import ActivityData

// MARK: - Suite: 챌린저 오프셋 검색 디코딩 계약

@Suite("ChallengerSearchOffsetDTO — 디코딩 매핑 (서버 contract)")
struct ChallengerSearchOffsetDTODecodingTests {

    private func decode(_ json: String) throws -> ChallengerSearchOffsetResultDTO {
        try JSONDecoder().decode(
            ChallengerSearchOffsetResultDTO.self,
            from: Data(json.utf8)
        )
    }

    @Test("숫자 식별자를 String 으로 통일하고 profileImageLink·roleTypes 를 매핑한다")
    func decodesIdentifiersAsStringAndMapsRoles() throws {
        let json = """
        {
          "page": {
            "content": [
              {
                "challengerId": 7, "memberId": 100, "gisuId": 70,
                "generation": 9, "gisu": 9, "part": "IOS", "name": "홍길동",
                "nickname": "길동", "schoolName": "한성대", "pointSum": 3,
                "profileImageLink": "https://img/1.png",
                "roleTypes": ["CHALLENGER", "BRAND_NEW_ROLE"]
              }
            ],
            "page": 0, "size": 20, "totalElements": 1, "totalPages": 1,
            "hasNext": false, "hasPrevious": false
          }
        }
        """

        let result = try decode(json)
        let item = try #require(result.page.content.first)

        #expect(item.challengerId == "7")
        #expect(item.memberId == "100")
        #expect(item.gisuId == "70")
        #expect(item.generation == 9)              // 표시 수치는 Int 유지
        #expect(item.profileImageURL == "https://img/1.png")
        #expect(item.roleTypes == [.challenger])   // 미지의 역할은 제외
    }

    @Test("page 필드가 없으면 빈 페이지로 폴백한다")
    func missingPageFallsBackToEmpty() throws {
        let dto = try decode("{}")

        #expect(dto.page.content.isEmpty)
        #expect(dto.page.hasNext == false)
    }

    @Test("generation/gisu 가 없으면 nil 로 디코딩한다")
    func optionalGenerationDecodesNil() throws {
        let json = """
        {
          "page": {
            "content": [
              {
                "challengerId": "7", "memberId": "100", "gisuId": "70",
                "part": "IOS", "name": "홍길동", "nickname": "길동",
                "schoolName": "한성대", "pointSum": 0, "roleTypes": []
              }
            ],
            "page": 0, "size": 20, "totalElements": 1, "totalPages": 1,
            "hasNext": false, "hasPrevious": false
          }
        }
        """

        let result = try decode(json)
        let item = try #require(result.page.content.first)

        #expect(item.generation == nil)
        #expect(item.gisu == nil)
        #expect(item.profileImageURL == nil)
    }
}
