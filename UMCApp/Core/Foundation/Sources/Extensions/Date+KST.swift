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

// MARK: - Constants

/// KST 하루 경계 계산에 쓰는 밀리초 기준값.
fileprivate enum Constants {
    /// KST 자정에서 그 날의 마지막 순간(23:59:59.999)까지 경과한 밀리초.
    static let endOfDayMilliseconds: Int = 86_399_999

    /// ``endOfDayMilliseconds`` 를 초 단위 오프셋으로 환산한 값.
    static let endOfDayOffset: TimeInterval = Double(endOfDayMilliseconds) / 1000
}

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

    /// KST 기준 그 날의 시작(00:00:00.000) 시각.
    var kstStartOfDay: Date {
        Calendar.kstGregorian.startOfDay(for: self)
    }

    /// KST 기준 그 날의 끝(23:59:59.**999**) 시각.
    ///
    /// 같은 날 자정에서 정확히 86_399_999ms 후의 시각을 반환합니다.
    /// 서버가 종일 일정의 종료 시각을 밀리초까지 채운 `23:59:59.999` 로 내려주므로,
    /// 초 단위(`23:59:59.000`)가 아닌 밀리초 단위를 경계값으로 삼습니다.
    var kstEndOfDay: Date {
        kstStartOfDay.addingTimeInterval(Constants.endOfDayOffset)
    }

    /// KST 기준 그 날의 시작 시각을 UTC ISO8601 문자열로 반환합니다.
    ///
    /// 서버에 "해당 날짜 00:00(KST)" 이후를 조회하는 파라미터로 사용합니다.
    var kstStartOfDayUTCISO8601: String {
        ServerDateTimeConverter.toUTCDateTimeString(kstStartOfDay)
    }

    /// KST 기준 그 날의 끝(23:59:59.999) 시각을 UTC ISO8601 문자열로 반환합니다.
    ///
    /// 예: 2026/02/15 KST 임의 시각 → `"2026-02-15T14:59:59.999Z"`
    var kstEndOfDayUTCISO8601: String {
        ServerDateTimeConverter.toUTCDateTimeString(kstEndOfDay)
    }
}

// MARK: - ClosedRange<Date>

public extension ClosedRange where Bound == Date {

    /// KST 기준으로 이 구간이 하루 전체(00:00:00.000 ~ 23:59:59.999)를 덮는지 여부.
    ///
    /// 서버가 종일 여부 플래그를 내려주지 않으므로, 응답의 시작/종료 시각만으로 판정합니다.
    /// 부동소수 등호 비교는 오차에 취약하므로 KST 자정으로부터 경과한 **밀리초**를
    /// 정수로 환산해 비교하며, 아래 세 조건을 모두 만족할 때 `true` 입니다.
    /// - 시작과 끝이 KST 기준 같은 날
    /// - 시작이 자정으로부터 0ms
    /// - 끝이 자정으로부터 86_399_999ms
    ///
    /// - Note: `ClosedRange` 는 `lowerBound > upperBound` 로 생성 시 트랩하므로
    ///   역전 구간 가드는 두지 않습니다.
    var isAllDayInKST: Bool {
        guard Calendar.kstGregorian.isDate(lowerBound, inSameDayAs: upperBound) else {
            return false
        }
        guard lowerBound.millisecondsSinceKSTStartOfDay == 0 else { return false }

        return upperBound.millisecondsSinceKSTStartOfDay == Constants.endOfDayMilliseconds
    }
}

// MARK: - Date + 밀리초 환산

fileprivate extension Date {

    /// KST 자정으로부터 경과한 밀리초. 부동소수 오차를 제거하기 위해 반올림해 정수로 환산합니다.
    var millisecondsSinceKSTStartOfDay: Int {
        Int((timeIntervalSince(kstStartOfDay) * 1000).rounded())
    }
}
