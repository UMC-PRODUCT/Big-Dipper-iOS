//
//  Date+KSTTests.swift
//  AppProductTests
//
//  Created by euijjang97 on 5/6/26.
//

@testable import AppProduct
import Foundation
import Testing

// MARK: - Helpers

private enum KSTTestHelper {

    /// KST 기준 (year/month/day hour:minute:second + millisecond) 으로 Date 생성
    static func makeKSTDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        millisecond: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.nanosecond = millisecond * 1_000_000

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: components)!
    }

    /// UTC ISO8601 (`yyyy-MM-dd'T'HH:mm:ss.SSSZ`) 문자열을 Date 로 파싱
    static func parseUTCISO8601(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)!
    }
}

// MARK: - kstStartOfDayUTCISO8601 / kstEndOfDayUTCISO8601

struct DateKSTSerializationTests {

    @Test("KST 자정 직렬화 — 임의 시각도 같은 KST 일자의 자정을 반환한다")
    func kstStartOfDayUTCISO8601_returnsKSTMidnightAsUTC() {
        let date = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 9,
            hour: 14, minute: 30, second: 45, millisecond: 678
        )

        #expect(date.kstStartOfDayUTCISO8601 == "2025-12-08T15:00:00.000Z")
    }

    @Test("KST 23:59:59.999 직렬화 — 임의 시각도 같은 KST 일자의 끝을 반환한다")
    func kstEndOfDayUTCISO8601_returnsKSTEndOfDayAsUTC() {
        let date = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 9,
            hour: 14, minute: 30, second: 45, millisecond: 678
        )

        #expect(date.kstEndOfDayUTCISO8601 == "2025-12-09T14:59:59.999Z")
    }

    @Test("이미 KST 자정인 시각도 동일하게 직렬화된다")
    func kstStartOfDay_atKSTMidnight_isStable() {
        let kstMidnight = KSTTestHelper.makeKSTDate(year: 2025, month: 12, day: 9)

        #expect(kstMidnight.kstStartOfDayUTCISO8601 == "2025-12-08T15:00:00.000Z")
    }

    @Test("연도 경계 — 2025/12/31 KST 자정 직렬화")
    func kstStartOfDayUTCISO8601_yearBoundary() {
        let date = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 31,
            hour: 23, minute: 0, second: 0
        )

        #expect(date.kstStartOfDayUTCISO8601 == "2025-12-30T15:00:00.000Z")
        #expect(date.kstEndOfDayUTCISO8601 == "2025-12-31T14:59:59.999Z")
    }
}

// MARK: - isAllDayInKST

struct DateKSTIsAllDayTests {

    @Test("✅ KST 00:00:00.000 ~ 23:59:59.999 단일 일자는 하루종일")
    func isAllDayInKST_exactBoundary_returnsTrue() {
        let start = KSTTestHelper.makeKSTDate(year: 2025, month: 12, day: 9)
        let end = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 9,
            hour: 23, minute: 59, second: 59, millisecond: 999
        )

        #expect((start...end).isAllDayInKST == true)
    }

    @Test("❌ start 가 1초 늦으면 하루종일 아님")
    func isAllDayInKST_startOneSecondLate_returnsFalse() {
        let start = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 9,
            hour: 0, minute: 0, second: 1
        )
        let end = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 9,
            hour: 23, minute: 59, second: 59, millisecond: 999
        )

        #expect((start...end).isAllDayInKST == false)
    }

    @Test("❌ end 가 다음날 자정이면 하루종일 아님")
    func isAllDayInKST_endIsNextDayMidnight_returnsFalse() {
        let start = KSTTestHelper.makeKSTDate(year: 2025, month: 12, day: 9)
        let end = KSTTestHelper.makeKSTDate(year: 2025, month: 12, day: 10)

        #expect((start...end).isAllDayInKST == false)
    }

    @Test("❌ 이틀에 걸치면 하루종일 아님")
    func isAllDayInKST_spansTwoDays_returnsFalse() {
        let start = KSTTestHelper.makeKSTDate(year: 2025, month: 12, day: 9)
        let end = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 10,
            hour: 23, minute: 59, second: 59, millisecond: 999
        )

        #expect((start...end).isAllDayInKST == false)
    }

    @Test("✅ UTC ISO8601 입력도 KST 환산 시 하루종일이면 true")
    func isAllDayInKST_utcInput_returnsTrue() {
        let start = KSTTestHelper.parseUTCISO8601("2025-12-08T15:00:00.000Z")
        let end = KSTTestHelper.parseUTCISO8601("2025-12-09T14:59:59.999Z")

        #expect((start...end).isAllDayInKST == true)
    }

    @Test("❌ end 의 ms 가 998 이면 (1ms 부족) 하루종일 아님")
    func isAllDayInKST_endOneMillisecondShort_returnsFalse() {
        let start = KSTTestHelper.makeKSTDate(year: 2025, month: 12, day: 9)
        let end = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 9,
            hour: 23, minute: 59, second: 59, millisecond: 998
        )

        #expect((start...end).isAllDayInKST == false)
    }

    @Test("✅ 연말 12/31 KST 단일 일자도 하루종일로 판정된다")
    func isAllDayInKST_yearEnd_returnsTrue() {
        let start = KSTTestHelper.makeKSTDate(year: 2025, month: 12, day: 31)
        let end = KSTTestHelper.makeKSTDate(
            year: 2025, month: 12, day: 31,
            hour: 23, minute: 59, second: 59, millisecond: 999
        )

        #expect((start...end).isAllDayInKST == true)
    }
}
