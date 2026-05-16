//
//  ScheduleIconCategoryTests.swift
//  UMCFoundationTests
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("ScheduleIconCategory — 서버 rawValue 매핑 (도메인 규칙)")
struct ScheduleIconCategoryTests {

    // MARK: - Raw Value Mapping

    @Test(
        "rawValue ↔ enum 매핑이 정확하다",
        arguments: [
            ("LEADERSHIP",   ScheduleIconCategory.leadership),
            ("STUDY",        .study),
            ("DUES",         .fee),
            ("MEETING",      .meeting),
            ("NETWORKING",   .networking),
            ("HACKATHON",    .hackathon),
            ("PROJECT",      .project),
            ("PRESENTATION", .presentation),
            ("WORKSHOP",     .workshop),
            ("RETROSPECTIVE", .review),
            ("AFTER_PARTY",  .celebration),
            ("ORIENTATION",  .orientation),
            ("TESTING",      .testing),
            ("GENERAL",      .general)
        ]
    )
    func rawValueMapping(rawValue: String, expected: ScheduleIconCategory) {
        let decoded = ScheduleIconCategory(rawValue: rawValue)

        #expect(decoded == expected)
        #expect(expected.rawValue == rawValue)
    }

    @Test("alllCases 는 14개를 포함한다")
    func allCasesCount() {
        #expect(ScheduleIconCategory.allCases.count == 14)
    }

    // MARK: - selectableCases

    @Test("selectableCases 는 testing 을 제외한다")
    func selectableExcludesTesting() {
        let selectable = ScheduleIconCategory.selectableCases

        #expect(selectable.contains(.testing) == false)
        #expect(selectable.count == ScheduleIconCategory.allCases.count - 1)
    }

    // MARK: - isDeprecated

    @Test("testing 카테고리는 isDeprecated=true")
    func testingIsDeprecated() {
        #expect(ScheduleIconCategory.testing.isDeprecated == true)
    }

    @Test("그 외 카테고리는 isDeprecated=false")
    func othersAreNotDeprecated() {
        for category in ScheduleIconCategory.allCases where category != .testing {
            #expect(category.isDeprecated == false, "Expected \(category) to not be deprecated")
        }
    }

    // MARK: - Korean

    @Test(
        "한글 명칭 매핑이 정확하다",
        arguments: [
            (ScheduleIconCategory.leadership, "리더십"),
            (.study, "스터디"),
            (.fee, "회비"),
            (.meeting, "회의"),
            (.networking, "네트워킹"),
            (.hackathon, "해커톤"),
            (.project, "프로젝트"),
            (.presentation, "발표"),
            (.workshop, "워크샵"),
            (.review, "회고"),
            (.celebration, "뒷풀이"),
            (.orientation, "오리엔테이션"),
            (.testing, "테스트"),
            (.general, "일반")
        ]
    )
    func koreanText(category: ScheduleIconCategory, expected: String) {
        #expect(category.korean == expected)
    }

    // MARK: - Codable

    @Test("Codable round-trip 시 동일한 케이스가 보존된다")
    func codableRoundTrip() throws {
        for original in ScheduleIconCategory.allCases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ScheduleIconCategory.self, from: data)

            #expect(decoded == original, "Round-trip failed for \(original)")
        }
    }

    @Test("알 수 없는 rawValue 디코딩 시 nil 반환")
    func unknownRawValueReturnsNil() {
        let decoded = ScheduleIconCategory(rawValue: "UNKNOWN_VALUE")

        #expect(decoded == nil)
    }
}
