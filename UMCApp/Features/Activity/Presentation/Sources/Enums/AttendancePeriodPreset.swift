//
//  AttendancePeriodPreset.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/14/26.
//

import Foundation
import UMCFoundation

// MARK: - AttendancePeriodPreset

/// 운영진 출석 현황 기간 필터 프리셋
///
/// 목록 조회의 `from`/`to` 범위를 프리셋 단위로 제공합니다. `.custom` 은
/// 사용자가 날짜를 직접 지정하므로 ``dateRange`` 가 `nil` 입니다.
///
/// - SeeAlso: ``OperatorAttendanceViewModel``
enum AttendancePeriodPreset: String, CaseIterable, Identifiable {
    case oneWeek     = "oneWeek"
    case oneMonth    = "oneMonth"
    case threeMonths = "threeMonths"
    case custom      = "custom"

    var id: String { rawValue }

    /// 필터 칩에 표시할 한국어 라벨
    var label: String {
        switch self {
        case .oneWeek:     return "최근 1주"
        case .oneMonth:    return "최근 1개월"
        case .threeMonths: return "최근 3개월"
        case .custom:      return "직접 입력"
        }
    }

    /// 필터 칩에 표시할 SF Symbol 이름
    var iconName: String {
        switch self {
        case .oneWeek, .oneMonth, .threeMonths: return "calendar"
        case .custom:                           return "calendar.badge.plus"
        }
    }

    // MARK: - Date Range

    /// 프리셋에 해당하는 `(fromDate, toDate)` 쌍.
    ///
    /// - `.custom` 은 날짜를 직접 지정하므로 `nil` 반환.
    /// - `toDate` 는 조회 시점 기준 +24시간으로 고정해 진행 중인 일정도 포함합니다.
    var dateRange: (fromDate: Date, toDate: Date)? {
        guard self != .custom else { return nil }
        let now = Date()
        let toDate = now.addingTimeInterval(24 * 60 * 60)
        let fromDate: Date
        switch self {
        case .oneWeek:
            fromDate = Calendar.kstGregorian.date(byAdding: .day, value: -7, to: now)
                ?? now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .oneMonth:
            fromDate = Calendar.kstGregorian.date(byAdding: .month, value: -1, to: now)
                ?? now.addingTimeInterval(-30 * 24 * 60 * 60)
        case .threeMonths:
            fromDate = Calendar.kstGregorian.date(byAdding: .month, value: -3, to: now)
                ?? now.addingTimeInterval(-90 * 24 * 60 * 60)
        case .custom:
            return nil
        }
        return (fromDate, toDate)
    }
}
