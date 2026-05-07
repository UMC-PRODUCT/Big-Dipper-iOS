//
//  Date+ScheduleDisplay.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

// MARK: - ClosedRange<Date> (일정 표시 헬퍼)

extension ClosedRange where Bound == Date {

    /// 일정 시간 범위 표시용 텍스트 (KST)
    ///
    /// - 하루종일(`isAllDayInKST`)이면 `"하루종일"` 반환
    /// - 그 외에는 `"HH:mm ~ HH:mm"` (KST 24시간제)
    ///
    /// 기존 `Date.timeRange(to:)` 가 시스템 시간대를 사용하는 것과 달리,
    /// 이 헬퍼는 `Asia/Seoul` (KST) 를 고정으로 적용합니다.
    var scheduleTimeRangeText: String {
        if isAllDayInKST {
            return "하루종일"
        }
        let formatter = ClosedRange.kstHourMinuteFormatter
        return "\(formatter.string(from: lowerBound)) ~ \(formatter.string(from: upperBound))"
    }

    /// 일정 날짜 범위 표시용 텍스트 (KST)
    ///
    /// - 시작·끝이 KST 기준 **같은 날**이면 `"yyyy.MM.dd (E)"` (예: `"2025.12.08 (일)"`)
    /// - 다른 날이면 `"M/d ~ M/d"` (예: `"12/8 ~ 12/9"`)
    var scheduleDateRangeText: String {
        let calendar = Calendar.kstGregorian
        if calendar.isDate(lowerBound, inSameDayAs: upperBound) {
            return ClosedRange.kstYearMonthDayWeekdayFormatter.string(from: lowerBound)
        }
        let shortFormatter = ClosedRange.kstMonthDayFormatter
        return "\(shortFormatter.string(from: lowerBound)) ~ \(shortFormatter.string(from: upperBound))"
    }
}

// MARK: - Formatters (private)

private extension ClosedRange where Bound == Date {

    static let kstHourMinuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        f.dateFormat = "HH:mm"
        return f
    }()

    static let kstYearMonthDayWeekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        f.dateFormat = "yyyy.MM.dd (E)"
        return f
    }()

    static let kstMonthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        f.dateFormat = "M/d"
        return f
    }()
}
