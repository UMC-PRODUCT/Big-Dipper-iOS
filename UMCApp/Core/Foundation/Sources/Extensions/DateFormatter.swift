//
//  DateFormatter.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

extension Date {
    // MARK: - Function

    /// "yyyy.MM.dd" 형식으로 변환 (예: "2026.01.17")
    public func toYearMonthDay() -> String {
        formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
            .replacingOccurrences(of: "/", with: ".")
    }
    
    /// "MM.dd" 형식으로 변환 (예: "01.17")
    public func toMonthDay() -> String {
        formatted(.dateTime.month(.twoDigits).day(.twoDigits))
            .replacingOccurrences(of: "/", with: ".")
    }
    
    /// "HH:mm" 24시간제 형식으로 변환 (예: "14:30")
    public func toHourMinutes() -> String {
        Date.hourMinuteFormatter.string(from: self)
    }
    
    /// 현재 시간 기준 상대적 시간 표현 (예: "3시간 전", "2일 전")
    public var timeAgoText: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        let weeks = Int(interval / 604800)
        let month = Int(interval / 2592000)
        
        if minutes < 1 {
            return "방금 전"
        } else if minutes < 60 {
            return "\(minutes)분 전"
        } else if hours < 24 {
            return "\(hours)시간 전"
        } else if days < 7 {
            return "\(days)일 전"
        } else if weeks < 4 {
            return "\(weeks)주 전"
        } else {
            return "\(month)개월 전"
        }
    }
    
    /// "HH:mm - HH:mm" 시간 범위 형식 (예: "14:00 - 18:00")
    public func timeRange(to endTime: Date) -> String {
        "\(self.toHourMinutes()) - \(endTime.toHourMinutes())"
    }
    
    /// "MM.dd - MM.dd" 날짜 범위 형식 (예: "01.17 - 01.20")
    public func dateRange(to endDate: Date) -> String {
        "\(self.toMonthDay()) - \(endDate.toMonthDay())"
    }

    /// "yyyy.MM.dd (E)" 형식으로 변환 (예: "2026.01.01 (토)")
    public func toYearMonthDayWithWeekday() -> String {
        formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).weekday(.abbreviated))
            .replacingOccurrences(of: "/", with: ".")
    }
    
    /// "MM.dd (E)" 형식으로 변환 (예: "01.01 (토)")
    public func toMonthDayWithWeekDay() -> String {
        formatted(.dateTime.month(.twoDigits).day(.twoDigits).weekday(.abbreviated))
            .replacingOccurrences(of: "/", with: ".")
    }
    
    /// "MM.dd (E) HH:mm" 형식으로 변환 (예: "01.01 (토) 19:00")
    public func toMonthDayWeekDayWithTime() -> String {
        "\(self.toMonthDayWithWeekDay()) \(self.toHourMinutes())"
    }

    // MARK: - Helper
}

private extension Date {
    // MARK: - Property

    static let hourMinuteFormatter: Foundation.DateFormatter = {
        let formatter = Foundation.DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
