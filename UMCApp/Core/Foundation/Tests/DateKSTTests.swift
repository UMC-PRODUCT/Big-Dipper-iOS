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

    /// 두 시각 사이의 경과 밀리초. 부동소수 오차를 배제하기 위해 반올림해 비교합니다.
    private func milliseconds(from start: Date, to end: Date) -> Int {
        Int((end.timeIntervalSince(start) * 1000).rounded())
    }

    @Test("kstStartOfDay 는 그 날 00:00(KST)")
    func startOfDay() {
        let start = kstDate().kstStartOfDay
        #expect(ServerDateTimeConverter.toKSTTimeString(start) == "00:00")
        #expect(ServerDateTimeConverter.toKSTDateString(start) == "2026-02-15")
    }

    @Test("kstEndOfDay 는 그 날 23:59:59.999(KST) — 자정 + 86_399_999ms")
    func endOfDay() {
        let day = kstDate()
        let end = day.kstEndOfDay
        #expect(ServerDateTimeConverter.toKSTTimeString(end) == "23:59")
        #expect(ServerDateTimeConverter.toKSTDateString(end) == "2026-02-15")
        #expect(milliseconds(from: day.kstStartOfDay, to: end) == 86_399_999)
    }

    @Test("kstEndOfDay 는 다음 날 자정보다 1ms 앞선다")
    func endOfDayIsBeforeNextMidnight() {
        let day = kstDate()
        let nextMidnight = Calendar.kstGregorian.date(
            byAdding: .day, value: 1, to: day.kstStartOfDay
        )!
        #expect(day.kstEndOfDay < nextMidnight)
        #expect(milliseconds(from: day.kstEndOfDay, to: nextMidnight) == 1)
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

    @Test("kstEndOfDayUTCISO8601 는 밀리초까지 채운 .999 로 직렬화된다")
    func endOfDayUTCISO8601HasMilliseconds() {
        #expect(kstDate().kstEndOfDayUTCISO8601 == "2026-02-15T14:59:59.999Z")
    }

    @Test("isAllDayInKST — 00:00:00.000~23:59:59.999 구간은 true")
    func isAllDayTrue() {
        let day = kstDate()
        let range = day.kstStartOfDay...day.kstEndOfDay
        #expect(range.isAllDayInKST == true)
    }

    @Test("isAllDayInKST — 종료가 23:59:59.999 면 true (서버 종일 일정 응답 형태)")
    func isAllDayTrueForMillisecondPreciseEnd() {
        let start = kstDate().kstStartOfDay
        let end = start.addingTimeInterval(86_399.999)
        #expect((start...end).isAllDayInKST == true)
    }

    @Test("isAllDayInKST — 서버 UTC ISO8601 문자열을 파싱한 구간도 true")
    func isAllDayTrueForParsedServerResponse() throws {
        let start = try #require(
            ServerDateTimeConverter.parseUTCDateTime("2026-02-14T15:00:00.000Z")
        )
        let end = try #require(
            ServerDateTimeConverter.parseUTCDateTime("2026-02-15T14:59:59.999Z")
        )
        #expect((start...end).isAllDayInKST == true)
    }

    @Test("isAllDayInKST — 종료가 23:59:59.000 이면 false")
    func isAllDayFalseForSecondPreciseEnd() {
        let start = kstDate().kstStartOfDay
        let end = start.addingTimeInterval(86_399)
        #expect((start...end).isAllDayInKST == false)
    }

    @Test("isAllDayInKST — 시작이 자정이 아니면 false")
    func isAllDayFalseWhenStartIsNotMidnight() {
        let day = kstDate()
        let start = day.kstStartOfDay.addingTimeInterval(1)
        #expect((start...day.kstEndOfDay).isAllDayInKST == false)
    }

    @Test("isAllDayInKST — 시작과 종료가 KST 기준 다른 날이면 false")
    func isAllDayFalseAcrossDifferentDays() {
        let start = kstDate().kstStartOfDay
        let end = kstDate(day: 16).kstEndOfDay
        #expect((start...end).isAllDayInKST == false)
    }

    @Test("isAllDayInKST — 부분 구간은 false")
    func isAllDayFalse() {
        let day = kstDate()
        let range = day.kstStartOfDay...day
        #expect(range.isAllDayInKST == false)
    }
}
