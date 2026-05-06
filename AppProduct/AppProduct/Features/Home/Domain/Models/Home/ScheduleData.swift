//
//  ScheduleData.swift
//  AppProduct
//
//  Created by euijjang97 on 1/18/26.
//

import Foundation

/// D-Day 텍스트 표시를 위한 공통 프로토콜
///
/// V1 의 `dDay: Int` 부호 규칙(양수 미래 / 0 오늘 / 음수 과거)을 그대로 유지합니다.
protocol ScheduleDDayDisplayable {
    var dDay: Int { get }
}

extension ScheduleDDayDisplayable {

    /// 서버의 dDay 부호 규칙에 맞춰 화면 표시용 문자열을 반환합니다.
    ///
    /// 양수는 미래 일정(D-N), 음수는 지난 일정(D+N), 0은 오늘 일정(D-Day)입니다.
    var dDayText: String {
        if dDay > 0 {
            return "D-\(dDay)"
        }
        if dDay < 0 {
            return "D+\(abs(dDay))"
        }
        return "D-Day"
    }
}
