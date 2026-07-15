//
//  Date+Calendar.swift
//  UMCFoundation
//
//  Created by euijjang97 on 7/5/26.
//
//  캘린더 UI(월 그리드, 요일 헤더 등) 구성에 필요한 날짜 계산 유틸리티.
//  KST 기준 그레고리력(`Calendar.kstGregorian`)을 사용합니다.
//

import Foundation

public extension Date {

    // MARK: - Month

    /// KST 기준 해당 월의 첫째 날 00:00 시각.
    var startOfMonth: Date {
        let calendar = Calendar.kstGregorian
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    /// KST 기준 해당 월의 마지막 날 00:00 시각.
    var endOfMonth: Date {
        let calendar = Calendar.kstGregorian
        let start = startOfMonth
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? self
    }

    /// KST 기준 해당 월에 포함된 모든 날짜(각 날의 00:00)를 순서대로 반환합니다.
    ///
    /// 월간 캘린더 그리드를 그릴 때 사용합니다.
    func datesInMonth() -> [Date] {
        let calendar = Calendar.kstGregorian
        guard let range = calendar.range(of: .day, in: .month, for: self) else {
            return []
        }

        let start = startOfMonth
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    // MARK: - Comparison

    /// KST 기준 같은 날(연·월·일)인지 여부.
    func isSameDay(_ other: Date) -> Bool {
        Calendar.kstGregorian.isDate(self, inSameDayAs: other)
    }
}

// MARK: - Weekday Symbols

public extension Date {

    /// 요일 심볼 표기 스타일.
    enum WeekdaySymbolStyle {
        /// 짧은 형태 (예: "일", "월")
        case short
        /// 매우 짧은 형태 (한국어에서는 `short`와 동일하게 동작)
        case veryShort
    }

    /// 한국어 로케일 기준 요일 심볼 배열(일요일 시작)을 반환합니다.
    ///
    /// - Parameter style: 심볼 표기 스타일.
    /// - Returns: `["일", "월", "화", "수", "목", "금", "토"]` 형태의 배열.
    static func weekDaySymbols(style: WeekdaySymbolStyle = .short) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")

        switch style {
        case .short:
            return calendar.shortWeekdaySymbols
        case .veryShort:
            return calendar.veryShortWeekdaySymbols
        }
    }
}
