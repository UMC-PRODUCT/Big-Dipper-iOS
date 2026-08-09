//
//  ScheduleCapabilitiesDTOTests.swift
//  HomeDataTests
//
//  Created by euijjang97 on 8/9/26.
//
//  서버가 `maxParticipantCount` 를 숫자로 주든 문자열로 주든 같은 도메인 값이 나오는지,
//  키 누락 시 크래시 없이 기본값으로 흡수되는지 검증한다.
//

import Foundation
import Testing
import HomeDomain
@testable import HomeData

@Suite("ScheduleCapabilitiesDTO — 디코딩 & 도메인 매핑")
struct ScheduleCapabilitiesDTOTests {

    @Test(
        "maxParticipantCount 가 숫자든 문자열이든 동일한 도메인 값으로 매핑된다",
        arguments: ["30", "\"30\""]
    )
    func decodesFlexibleMaxParticipantCount(rawValue: String) throws {
        let json = """
        {
            "canCreateSchedule": true,
            "canCreateAttendanceRequiredSchedule": true,
            "maxParticipantCount": \(rawValue)
        }
        """

        let domain = try decodeCapabilities(json).toDomain()

        #expect(domain.canCreateSchedule)
        #expect(domain.canCreateAttendanceRequiredSchedule)
        #expect(domain.maxParticipantCount == "30")
    }

    @Test("키가 누락되면 권한 없음 · 초대 인원 0 으로 흡수된다")
    func missingKeysFallBackToDefaults() throws {
        let domain = try decodeCapabilities("{}").toDomain()

        #expect(domain.canCreateSchedule == false)
        #expect(domain.canCreateAttendanceRequiredSchedule == false)
        #expect(domain.maxParticipantCount == "0")
    }
}

// MARK: - Helpers

private func decodeCapabilities(_ json: String) throws -> ScheduleCapabilitiesDTO {
    try JSONDecoder().decode(ScheduleCapabilitiesDTO.self, from: Data(json.utf8))
}
