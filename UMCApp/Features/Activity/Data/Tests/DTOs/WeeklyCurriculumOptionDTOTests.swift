//
//  WeeklyCurriculumOptionDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Testing
import ActivityDomain
@testable import ActivityData

// MARK: - Helpers

private func decodeOption(_ json: String) throws -> WeeklyCurriculumOptionDTO {
    try JSONDecoder().decode(WeeklyCurriculumOptionDTO.self, from: Data(json.utf8))
}

private func decodeOptionsResponse(_ json: String) throws -> WeeklyCurriculumOptionsResponseDTO {
    try JSONDecoder().decode(WeeklyCurriculumOptionsResponseDTO.self, from: Data(json.utf8))
}

@Suite("WeeklyCurriculumOptionDTO — 디코딩/매핑")
struct WeeklyCurriculumOptionDTOTests {

    // MARK: - Single DTO Decoding

    @Test("단일 옵션 JSON 의 모든 필드를 디코딩한다")
    func decodesSingleOption() throws {
        let dto = try decodeOption(#"""
        { "weeklyCurriculumId": "5001", "weekNo": "1", "title": "1주차" }
        """#)

        #expect(dto.weeklyCurriculumId == "5001")
        #expect(dto.weekNo == "1")
        #expect(dto.title == "1주차")
    }

    @Test("weeklyCurriculumId 와 weekNo 가 JSON 숫자로 와도 String 으로 디코딩한다")
    func decodesNumericIdsAsString() throws {
        let dto = try decodeOption(#"""
        { "weeklyCurriculumId": 5001, "weekNo": 1, "title": "1주차" }
        """#)

        #expect(dto.weeklyCurriculumId == "5001")
        #expect(dto.weekNo == "1")
    }

    @Test("필드가 없으면 빈 문자열 기본값으로 디코딩한다")
    func decodesWithDefaults() throws {
        let dto = try decodeOption("{}")

        #expect(dto.weeklyCurriculumId == "")
        #expect(dto.weekNo == "")
        #expect(dto.title == "")
    }

    @Test("custom encode 후 다시 디코딩하면 동일한 DTO 가 복원된다")
    func encodeRoundTrip() throws {
        let original = try decodeOption(#"""
        { "weeklyCurriculumId": "5001", "weekNo": "1", "title": "1주차" }
        """#)
        let restored = try JSONDecoder().decode(
            WeeklyCurriculumOptionDTO.self,
            from: JSONEncoder().encode(original)
        )
        #expect(restored == original)
    }

    // MARK: - toDomain (single)

    @Test("toDomain — weeklyCurriculumId/weekNo/title 을 도메인 모델로 매핑한다")
    func toDomainMapsFields() throws {
        let option = try decodeOption(#"""
        { "weeklyCurriculumId": "5001", "weekNo": "2", "title": "2주차 미션" }
        """#).toDomain()

        #expect(option.weeklyCurriculumId == "5001")
        #expect(option.weekNo == "2")
        #expect(option.title == "2주차 미션")
        #expect(option.id == "5001")
    }

    // MARK: - Response Wrapper Decoding (multi-format)

    @Test("응답 — 최상위 배열 포맷을 옵션 목록으로 디코딩한다")
    func decodesTopLevelArray() throws {
        let response = try decodeOptionsResponse(#"""
        [
            { "weeklyCurriculumId": "1", "weekNo": "1", "title": "1주차" },
            { "weeklyCurriculumId": "2", "weekNo": "2", "title": "2주차" }
        ]
        """#)

        #expect(response.options.count == 2)
        #expect(response.options.map(\.weekNo) == ["1", "2"])
    }

    @Test("응답 — content 키 래핑 포맷을 옵션 목록으로 디코딩한다")
    func decodesContentKeyWrapped() throws {
        let response = try decodeOptionsResponse(#"""
        { "content": [ { "weeklyCurriculumId": "1", "weekNo": "1", "title": "1주차" } ] }
        """#)

        #expect(response.options.count == 1)
        #expect(response.options.first?.weeklyCurriculumId == "1")
    }

    @Test("응답 — weeklyCurriculums 키 포맷을 옵션 목록으로 디코딩한다")
    func decodesWeeklyCurriculumsKey() throws {
        let response = try decodeOptionsResponse(#"""
        { "weeklyCurriculums": [ { "weeklyCurriculumId": "9", "weekNo": "3", "title": "3주차" } ] }
        """#)

        #expect(response.options.count == 1)
        #expect(response.options.first?.weekNo == "3")
    }

    @Test("응답 — 인식 가능한 키가 없으면 빈 옵션 목록으로 디코딩한다")
    func decodesEmptyWhenNoRecognizedKey() throws {
        let response = try decodeOptionsResponse(#"{ "other": [] }"#)
        #expect(response.options.isEmpty)
    }

    @Test("응답 — 빈 배열을 빈 옵션 목록으로 디코딩한다")
    func decodesEmptyArray() throws {
        let response = try decodeOptionsResponse("[]")
        #expect(response.options.isEmpty)
    }

    // MARK: - toDomain (list)

    @Test("toDomain — 응답 목록을 도메인 모델 배열로 변환한다")
    func toDomainMapsList() throws {
        let options = try decodeOptionsResponse(#"""
        { "content": [
            { "weeklyCurriculumId": "1", "weekNo": "1", "title": "1주차" },
            { "weeklyCurriculumId": "2", "weekNo": "2", "title": "2주차" }
        ] }
        """#).toDomain()

        #expect(options.count == 2)
        #expect(options.map(\.weeklyCurriculumId) == ["1", "2"])
        #expect(options.map(\.title) == ["1주차", "2주차"])
    }

    @Test("응답 — custom encode 는 content 키로 직렬화되어 round-trip 된다")
    func responseEncodeRoundTrip() throws {
        let original = try decodeOptionsResponse(#"""
        { "content": [ { "weeklyCurriculumId": "1", "weekNo": "1", "title": "1주차" } ] }
        """#)
        let restored = try JSONDecoder().decode(
            WeeklyCurriculumOptionsResponseDTO.self,
            from: JSONEncoder().encode(original)
        )
        #expect(restored == original)
    }
}
