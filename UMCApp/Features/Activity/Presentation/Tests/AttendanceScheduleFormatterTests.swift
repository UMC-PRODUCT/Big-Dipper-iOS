//
//  AttendanceScheduleFormatterTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 7/25/26.
//

import Foundation
import Testing
@testable import ActivityPresentation

// MARK: - Helpers

/// 1970-01-01 09:00 KST (목) — 실행 환경 타임존과 무관하게 고정된 기준 시각.
private let kstMorning = Date(timeIntervalSince1970: 0)

/// 1970-01-01 12:00 KST — `kstMorning` + 3시간.
private let kstNoon = Date(timeIntervalSince1970: 10_800)

// MARK: - 일시 범위

@Suite("AttendanceScheduleFormatter — 일시 범위 표기 (도메인 규칙)")
struct AttendanceScheduleFormatterDateRangeTests {

    @Test(
        "정상 범위 → '시작 일시 ~ 종료 시각' (스타일별로 시작 포맷만 달라진다)",
        arguments: [
            (AttendanceScheduleFormatter.DateRangeStyle.list, "1월 1일 (목) 09:00 ~ 12:00"),
            (AttendanceScheduleFormatter.DateRangeStyle.detail, "1970.1.1 (목) 09:00 ~ 12:00")
        ]
    )
    func dateRangeTextForValidRange(
        style: AttendanceScheduleFormatter.DateRangeStyle,
        expected: String
    ) {
        let text = AttendanceScheduleFormatter.dateRangeText(
            from: kstMorning,
            to: kstNoon,
            style: style
        )

        #expect(text == expected)
    }

    @Test("시작 == 종료 → 경계값도 범위로 표기한다")
    func dateRangeTextForZeroLengthRange() {
        let text = AttendanceScheduleFormatter.dateRangeText(
            from: kstMorning,
            to: kstMorning,
            style: .list
        )

        #expect(text == "1월 1일 (목) 09:00 ~ 09:00")
    }

    @Test("시작 > 종료(비정상 범위) → 거꾸로 읽히지 않도록 시작 일시만 표기한다")
    func dateRangeTextForInvertedRange() {
        let text = AttendanceScheduleFormatter.dateRangeText(
            from: kstNoon,
            to: kstMorning,
            style: .list
        )

        #expect(text == "1월 1일 (목) 12:00")
    }
}

// MARK: - 출석률

@Suite("AttendanceScheduleFormatter — 출석률 표기 (도메인 규칙)")
struct AttendanceScheduleFormatterRateTests {

    @Test("참여자가 없으면 분모가 0이라 '—' 로 표기한다")
    func attendanceRateTextForEmptySchedule() {
        let text = AttendanceScheduleFormatter.attendanceRateText(rate: 0, totalCount: 0)

        #expect(text == "—")
    }

    @Test(
        "참여자가 있으면 백분율을 반올림해 표기한다",
        arguments: [
            (2.0 / 3.0, 3, "67%"),
            (1.0, 5, "100%"),
            (0.0, 4, "0%")
        ]
    )
    func attendanceRateTextRoundsPercent(rate: Double, totalCount: Int, expected: String) {
        let text = AttendanceScheduleFormatter.attendanceRateText(
            rate: rate,
            totalCount: totalCount
        )

        #expect(text == expected)
    }
}
