//
//  Date+KST.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

// MARK: - TimeZone

extension TimeZone {
    /// Asia/Seoul (KST, UTC+9, DST 없음)
    static let kst: TimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
}

// MARK: - Calendar

extension Calendar {
    /// KST 기반 그레고리력 캘린더
    static let kstGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .kst
        return calendar
    }()
}

// MARK: - Date (KST 자정 / 23:59:59.999)

extension Date {

    /// KST 기준 자정(00:00:00.000) 시각
    var kstStartOfDay: Date {
        Calendar.kstGregorian.startOfDay(for: self)
    }

    /// KST 기준 23:59:59.999 시각
    ///
    /// 같은 날의 자정에서 정확히 86_399_999 ms 후의 시각을 반환합니다.
    var kstEndOfDay: Date {
        kstStartOfDay.addingTimeInterval(Self.endOfDayOffsetSeconds)
    }

    /// 자정으로부터 23:59:59.999 까지의 초 단위 오프셋
    fileprivate static let endOfDayOffsetSeconds: TimeInterval = 86_399.999
}

// MARK: - Date (UTC ISO8601 직렬화)

extension Date {

    /// KST 자정(00:00:00.000) Date 를 UTC ISO8601 (`yyyy-MM-dd'T'HH:mm:ss.SSSZ`) 문자열로 직렬화
    ///
    /// 예: 2025/12/09 KST 임의 시각 → `"2025-12-08T15:00:00.000Z"`
    var kstStartOfDayUTCISO8601: String {
        Self.utcISO8601String(from: kstStartOfDay)
    }

    /// KST 23:59:59.999 Date 를 UTC ISO8601 (`yyyy-MM-dd'T'HH:mm:ss.SSSZ`) 문자열로 직렬화
    ///
    /// 예: 2025/12/09 KST 임의 시각 → `"2025-12-09T14:59:59.999Z"`
    var kstEndOfDayUTCISO8601: String {
        Self.utcISO8601String(from: kstEndOfDay)
    }

    private static func utcISO8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

// MARK: - ClosedRange<Date> (하루종일 판정)

extension ClosedRange where Bound == Date {

    /// 구간이 KST 기준으로 정확히 [00:00:00.000 ~ 23:59:59.999] 인 단일 일자인지 판정
    ///
    /// 서버가 `isAllDay` 필드를 더 이상 관리하지 않게 됨에 따라,
    /// 클라이언트가 응답의 `startsAt`/`endsAt` 을 보고 직접 하루종일 일정인지 판정해야 합니다.
    ///
    /// 부동소수 오차를 피하기 위해 KST 자정으로부터 경과한 **밀리초** 를 정수로 환산해 비교합니다.
    /// - 시작이 KST 자정으로부터 0 ms
    /// - 끝이 KST 자정으로부터 86_399_999 ms
    /// - 시작과 끝이 KST 기준 같은 일자
    /// 위 세 조건을 모두 만족하면 `true`.
    var isAllDayInKST: Bool {
        let calendar = Calendar.kstGregorian

        guard calendar.isDate(lowerBound, inSameDayAs: upperBound) else {
            return false
        }

        let startMs = Self.msSinceKSTStartOfDay(lowerBound, calendar: calendar)
        guard startMs == 0 else { return false }

        let endMs = Self.msSinceKSTStartOfDay(upperBound, calendar: calendar)
        return endMs == 86_399_999
    }

    private static func msSinceKSTStartOfDay(
        _ date: Date,
        calendar: Calendar
    ) -> Int {
        let kstStart = calendar.startOfDay(for: date)
        let interval = date.timeIntervalSince(kstStart)
        return Int((interval * 1000).rounded())
    }
}
