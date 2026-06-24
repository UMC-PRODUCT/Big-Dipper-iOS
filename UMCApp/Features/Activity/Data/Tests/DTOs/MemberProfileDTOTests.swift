//
//  MemberProfileDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/24/26.
//

import Foundation
import Testing
@testable import ActivityData

@Suite("MemberProfileDTO — 챌린저 레코드 디코딩 (서버 contract)")
struct MemberProfileDTOTests {

    // MARK: - Helpers

    private func decode(_ json: String) throws -> MemberProfileDTO {
        try JSONDecoder().decode(MemberProfileDTO.self, from: Data(json.utf8))
    }

    // MARK: - challengerRecords

    @Test("challengerRecords 를 String 식별자로 디코딩한다")
    func decodesRecordsWithStringIdentifiers() throws {
        let dto = try decode("""
        {
          "challengerRecords": [
            { "challengerId": "10", "memberId": "100", "gisu": 7, "gisuId": "70" }
          ]
        }
        """)

        let record = try #require(dto.challengerRecords.first)
        #expect(dto.challengerRecords.count == 1)
        #expect(record.challengerId == "10")
        #expect(record.memberId == "100")
        #expect(record.gisu == 7)
        #expect(record.gisuId == "70")
    }

    @Test("숫자로 내려온 식별자도 String 으로 디코딩한다 (유연 디코딩)")
    func decodesNumericIdentifiersAsString() throws {
        let dto = try decode("""
        {
          "challengerRecords": [
            { "challengerId": 10, "memberId": 100, "gisu": "7", "gisuId": 70 }
          ]
        }
        """)

        let record = try #require(dto.challengerRecords.first)
        #expect(record.challengerId == "10")
        #expect(record.memberId == "100")
        #expect(record.gisu == 7)
        #expect(record.gisuId == "70")
    }

    @Test("challengerRecords 키가 없으면 빈 배열로 디코딩한다")
    func decodesMissingRecordsAsEmpty() throws {
        let dto = try decode("{}")
        #expect(dto.challengerRecords.isEmpty)
    }
}
