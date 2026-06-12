//
//  Date+HourMinutes.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/12/26.
//

import Foundation

extension Date {

    /// "HH:mm" 24시간제 형식으로 변환 (예: "14:30")
    ///
    /// 출석 정책의 마감 시각 표시(`attendanceGuidanceText`)에 사용합니다.
    func toHourMinutes() -> String {
        Date.hourMinuteFormatter.string(from: self)
    }
}

private extension Date {

    static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
