//
//  DateKSTTests.swift
//  UMCFoundationTests
//
//  Created by euijjang97 on 7/5/26.
//
//  KST 유틸리티는 고정 KST 캘린더를 쓰므로 실행 머신의 타임존과 무관하게 결정적입니다.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("Date+KST — KST 경계 계산")
struct DateKSTTests {

    /// KST 기준 특정 시각(2026-02-15 13:45 KST)을 생성합니다.
    private func kstDate(
        year: Int = 2026, month: Int = 2, day: Int = 15,
        hour: Int = 13, minute: Int = 45
    ) -> Date {
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )
        return Calendar.kstGregorian.date(from: components)!
    }

    @Test("kstStartOfDay 는 그 날 00:00(KST)")
    func startOfDay() {
        let start = kstDate().kstStartOfDay
        #expect(ServerDateTimeConverter.toKSTTimeString(start) == "00:00")
        #expect(ServerDateTimeConverter.toKSTDateString(start) == "2026-02-15")
    }

    @Test("kstEndOfDay 는 그 날 23:59(KST)")
    func endOfDay() {
        let end = kstDate().kstEndOfDay
        #expect(ServerDateTimeConverter.toKSTTimeString(end) == "23:59")
        #expect(ServerDateTimeConverter.toKSTDateString(end) == "2026-02-15")
    }

    @Test("start ≤ 원본 ≤ end 순서가 성립한다")
    func ordering() {
        let date = kstDate()
        #expect(date.kstStartOfDay <= date)
        #expect(date <= date.kstEndOfDay)
    }

    @Test("kstStartOfDayUTCISO8601 는 파싱 시 원래 시작 시각으로 복원된다")
    func utcISO8601RoundTrip() {
        let date = kstDate()
        let iso = date.kstStartOfDayUTCISO8601
        let parsed = ServerDateTimeConverter.parseUTCDateTime(iso)
        #expect(parsed == date.kstStartOfDay)
    }

    @Test("isAllDayInKST — 00:00~23:59 구간은 true")
    func isAllDayTrue() {
        let day = kstDate()
        let range = day.kstStartOfDay...day.kstEndOfDay
        #expect(range.isAllDayInKST == true)
    }

    @Test("isAllDayInKST — 부분 구간은 false")
    func isAllDayFalse() {
        let day = kstDate()
        let range = day.kstStartOfDay...day
        #expect(range.isAllDayInKST == false)
    }
}
