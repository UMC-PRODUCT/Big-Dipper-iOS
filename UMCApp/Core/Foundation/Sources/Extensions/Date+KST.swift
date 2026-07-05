//
//  Date+KST.swift
//  UMCFoundation
//
//  Created by euijjang97 on 7/5/26.
//
//  KST(Asia/Seoul) 타임존 경계를 다루기 위한 유틸리티.
//  서버는 UTC 기준으로 시각을 저장하지만, 화면 표시와 "하루 종일" 판정은
//  한국 로컬 기준이어야 하므로 KST 경계 계산을 이 파일로 모읍니다.
//

import Foundation

// MARK: - TimeZone / Calendar

public extension TimeZone {
    /// 한국 표준시(Asia/Seoul). 식별자 조회 실패 시 현재 타임존으로 폴백합니다.
    static let kst: TimeZone = .init(identifier: "Asia/Seoul") ?? .current
}

public extension Calendar {
    /// KST 기준 그레고리력 캘린더.
    static let kstGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .kst
        return calendar
    }()
}

// MARK: - Date + KST 경계

public extension Date {

    /// KST 기준 그 날의 시작(00:00:00) 시각.
    var kstStartOfDay: Date {
        Calendar.kstGregorian.startOfDay(for: self)
    }

    /// KST 기준 그 날의 끝(다음 날 00:00:00 직전) 시각.
    var kstEndOfDay: Date {
        let calendar = Calendar.kstGregorian
        let start = calendar.startOfDay(for: self)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? self
    }

    /// KST 기준 그 날의 시작 시각을 UTC ISO8601 문자열로 반환합니다.
    ///
    /// 서버에 "해당 날짜 00:00(KST)" 이후를 조회하는 파라미터로 사용합니다.
    var kstStartOfDayUTCISO8601: String {
        ServerDateTimeConverter.toUTCDateTimeString(kstStartOfDay)
    }

    /// KST 기준 그 날의 끝 시각을 UTC ISO8601 문자열로 반환합니다.
    var kstEndOfDayUTCISO8601: String {
        ServerDateTimeConverter.toUTCDateTimeString(kstEndOfDay)
    }
}

// MARK: - ClosedRange<Date>

public extension ClosedRange where Bound == Date {

    /// KST 기준으로 이 구간이 하루 전체(00:00 ~ 23:59:59)를 덮는지 여부.
    ///
    /// 종일 일정(all-day) 판정에 사용합니다.
    var isAllDayInKST: Bool {
        lowerBound == lowerBound.kstStartOfDay && upperBound == lowerBound.kstEndOfDay
    }
}
