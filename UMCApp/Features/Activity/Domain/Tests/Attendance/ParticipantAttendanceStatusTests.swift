//
//  ParticipantAttendanceStatusTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import Testing
@testable import ActivityDomain

// MARK: - Helpers

private func decode(rawJSON: String) throws -> ParticipantAttendanceStatus {
    let data = Data(rawJSON.utf8)
    return try JSONDecoder().decode(ParticipantAttendanceStatus.self, from: data)
}

// MARK: - Suite

@Suite("ParticipantAttendanceStatus — 디코딩 / 필터 / 분기 도메인 규칙")
struct ParticipantAttendanceStatusTests {

    // MARK: - Decoding

    @Test(
        "서버 raw 값이 정의된 케이스이면 그 케이스로 디코딩된다",
        arguments: [
            ("\"PRESENT\"", ParticipantAttendanceStatus.present),
            ("\"LATE\"", .late),
            ("\"ABSENT\"", .absent),
            ("\"EXCUSED\"", .excused),
            ("\"PRESENT_PENDING\"", .presentPending),
            ("\"LATE_PENDING\"", .latePending),
            ("\"EXCUSED_PENDING\"", .excusedPending),
            ("\"PENDING\"", .pending)
        ]
    )
    func decodesKnownRawValues(rawJSON: String, expected: ParticipantAttendanceStatus) throws {
        // Given
        // (입력: rawJSON)

        // When
        let status = try decode(rawJSON: rawJSON)

        // Then
        #expect(status == expected)
    }

    @Test("서버가 미정의 raw 값을 보내면 unknown 으로 폴백 디코딩한다")
    func decodesUnknownRawValueAsUnknown() throws {
        // Given
        let rawJSON = "\"BRAND_NEW_STATUS\""

        // When
        let status = try decode(rawJSON: rawJSON)

        // Then
        #expect(status == .unknown)
    }

    // MARK: - filterableCases

    @Test("filterableCases 는 unknown 을 제외한 모든 케이스를 반환한다")
    func filterableCasesExcludesUnknown() {
        // Given
        let allCases = ParticipantAttendanceStatus.allCases

        // When
        let filterable = ParticipantAttendanceStatus.filterableCases

        // Then
        #expect(filterable.contains(.unknown) == false)
        #expect(filterable.count == allCases.count - 1)
    }

    // MARK: - serverQueryValue

    @Test("정의된 케이스의 serverQueryValue 는 raw 값을 그대로 반환한다")
    func serverQueryValueReturnsRawForKnownCase() {
        // Given
        let status = ParticipantAttendanceStatus.present

        // When
        let value = status.serverQueryValue

        // Then
        #expect(value == "PRESENT")
    }

    @Test("unknown 의 serverQueryValue 는 nil 이다 (서버 전송 차단)")
    func serverQueryValueReturnsNilForUnknown() {
        // Given
        let status = ParticipantAttendanceStatus.unknown

        // When
        let value = status.serverQueryValue

        // Then
        #expect(value == nil)
    }

    // MARK: - isPending

    @Test(
        "isPending 은 *_PENDING 계열만 true 를 반환한다",
        arguments: [
            (ParticipantAttendanceStatus.presentPending, true),
            (.latePending, true),
            (.excusedPending, true),
            (.present, false),
            (.late, false),
            (.absent, false),
            (.excused, false),
            (.pending, false),
            (.unknown, false)
        ]
    )
    func isPendingMatchesPendingFamilyOnly(
        status: ParticipantAttendanceStatus,
        expected: Bool
    ) {
        // Given
        // (입력: status)

        // When
        let isPending = status.isPending

        // Then
        #expect(isPending == expected)
    }

    // MARK: - badgeText

    @Test("unknown 의 badgeText 는 displayText 가 아닌 '알 수 없음' 단축 텍스트다")
    func badgeTextShortensUnknown() {
        // Given
        let status = ParticipantAttendanceStatus.unknown

        // When
        let badge = status.badgeText
        let display = status.displayText

        // Then
        #expect(badge == "알 수 없음")
        #expect(display == "상태 미지정")
        #expect(badge != display)
    }

    @Test("unknown 이 아닌 케이스의 badgeText 는 displayText 와 일치한다")
    func badgeTextMatchesDisplayForKnownCase() {
        // Given
        let status = ParticipantAttendanceStatus.present

        // When
        let badge = status.badgeText
        let display = status.displayText

        // Then
        #expect(badge == display)
    }
}
