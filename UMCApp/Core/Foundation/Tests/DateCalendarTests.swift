//
//  DateCalendarTests.swift
//  UMCFoundationTests
//
//  Created by euijjang97 on 7/5/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("Date+Calendar — 월/요일 계산")
struct DateCalendarTests {

    /// KST 기준 2026-02-15 12:00 (2026년은 평년 → 2월 28일).
    private func februaryDate() -> Date {
        Calendar.kstGregorian.date(
            from: DateComponents(year: 2026, month: 2, day: 15, hour: 12)
        )!
    }

    @Test("startOfMonth 는 그 달 1일")
    func startOfMonth() {
        let start = februaryDate().startOfMonth
        #expect(ServerDateTimeConverter.toKSTDateString(start) == "2026-02-01")
    }

    @Test("endOfMonth 는 그 달 마지막 날 (2026-02 → 28일)")
    func endOfMonth() {
        let end = februaryDate().endOfMonth
        #expect(ServerDateTimeConverter.toKSTDateString(end) == "2026-02-28")
    }

    @Test("datesInMonth 는 그 달의 모든 날(평년 2월 = 28개)을 반환한다")
    func datesInMonthCount() {
        let dates = februaryDate().datesInMonth()
        #expect(dates.count == 28)
        #expect(ServerDateTimeConverter.toKSTDateString(dates.first!) == "2026-02-01")
        #expect(ServerDateTimeConverter.toKSTDateString(dates.last!) == "2026-02-28")
    }

    @Test("datesInMonth — 윤년 2월은 29개 (2028-02)")
    func datesInMonthLeapYear() {
        let leap = Calendar.kstGregorian.date(
            from: DateComponents(year: 2028, month: 2, day: 10, hour: 12)
        )!
        #expect(leap.datesInMonth().count == 29)
    }

    @Test("isSameDay — 같은 KST 날짜의 다른 시각은 true")
    func isSameDayTrue() {
        let calendar = Calendar.kstGregorian
        let morning = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 1))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 23))!
        #expect(morning.isSameDay(evening) == true)
    }

    @Test("isSameDay — 다른 날짜는 false")
    func isSameDayFalse() {
        let calendar = Calendar.kstGregorian
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 16))!
        #expect(day1.isSameDay(day2) == false)
    }

    @Test("weekDaySymbols — 일요일 시작, 7개")
    func weekDaySymbols() {
        let symbols = Date.weekDaySymbols(style: .short)
        #expect(symbols.count == 7)
        #expect(symbols.first == "일")
        #expect(symbols.last == "토")
    }
}
