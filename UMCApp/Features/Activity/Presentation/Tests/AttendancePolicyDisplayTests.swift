//
//  AttendancePolicyDisplayTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 8/2/26.
//

import Foundation
import Testing
import UMCFoundation

@testable import ActivityPresentation

// MARK: - Helper

/// 지정한 KST 시각. 기기 타임존과 무관하게 같은 절대 시각을 만든다.
private func makeKSTDate(
    year: Int = 2026,
    month: Int = 5,
    day: Int,
    hour: Int,
    minute: Int = 0
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute

    guard let date = Calendar.kstGregorian.date(from: components) else {
        Issue.record("Failed to construct KST test date")
        return Date(timeIntervalSince1970: 0)
    }
    return date
}

// MARK: - 정책 시각 표기

@Suite("출석 정책 시각 표기 (도메인 규칙)")
struct AttendancePolicyDisplayTests {

    @Test("기준일과 같은 날이면 시각만 표시한다")
    func sameDayShowsTimeOnly() {
        let anchor = makeKSTDate(day: 7, hour: 13, minute: 50)
        let onTimeEnd = makeKSTDate(day: 7, hour: 14, minute: 10)

        #expect(onTimeEnd.attendancePolicyText(anchoredAt: anchor) == "14:10")
    }

    @Test("자정을 넘긴 마감은 날짜를 함께 표시한다")
    func crossMidnightShowsDate() {
        let anchor = makeKSTDate(day: 7, hour: 23, minute: 50)
        let lateEnd = makeKSTDate(day: 8, hour: 0, minute: 30)

        #expect(lateEnd.attendancePolicyText(anchoredAt: anchor) == "5/8 00:30")
    }

    /// 회귀 박제 — 날짜 부분을 공용 `toMonthDay()` 로 되돌리면 여기서 깨진다.
    ///
    /// 그 헬퍼는 (1) 타임존 미지정이라 기기 타임존을 따르고(자정 근처에서 KST 시각과
    /// 하루가 어긋남), (2) 로케일에 따라 `"05. 08."` 처럼 다르게 렌더한다.
    /// 두 결함 모두 이 단언의 `"5/8"` 을 통과하지 못한다.
    @Test("날짜 부분은 KST 기준 M/d 표기를 유지한다")
    func crossMidnightKeepsKSTMonthDayFormat() {
        let anchor = makeKSTDate(day: 7, hour: 23, minute: 50)
        let lateEnd = makeKSTDate(day: 8, hour: 0, minute: 30)

        let text = lateEnd.attendancePolicyText(anchoredAt: anchor)

        #expect(text.hasPrefix("5/8"))
    }
}
