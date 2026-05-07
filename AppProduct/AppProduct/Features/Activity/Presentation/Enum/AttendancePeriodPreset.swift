//
//  AttendancePeriodPreset.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

// MARK: - AttendancePeriodPreset

/// 출석 현황 기간 필터 프리셋
///
/// - SeeAlso: ``AttendanceListViewModel``
enum AttendancePeriodPreset: String, CaseIterable, Identifiable {
    case oneWeek     = "oneWeek"
    case oneMonth    = "oneMonth"
    case threeMonths = "threeMonths"
    case custom      = "custom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneWeek:     return "최근 1주"
        case .oneMonth:    return "최근 1개월"
        case .threeMonths: return "최근 3개월"
        case .custom:      return "직접 입력"
        }
    }

    // MARK: - Date Range

    /// 프리셋에 해당하는 `(fromDate, toDate)` 쌍을 반환합니다.
    ///
    /// - `.custom` 은 날짜를 직접 지정하므로 `nil` 반환.
    /// - `toDate` 는 조회 시점 기준 +24시간으로 고정하여 진행 중인 일정도 포함합니다.
    var dateRange: (fromDate: Date, toDate: Date)? {
        guard self != .custom else { return nil }
        let now = Date()
        let toDate = now.addingTimeInterval(24 * 60 * 60)
        let fromDate: Date
        switch self {
        case .oneWeek:
            fromDate = Calendar.kstGregorian.date(
                byAdding: .day, value: -7, to: now
            ) ?? now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .oneMonth:
            fromDate = Calendar.kstGregorian.date(
                byAdding: .month, value: -1, to: now
            ) ?? now.addingTimeInterval(-30 * 24 * 60 * 60)
        case .threeMonths:
            fromDate = Calendar.kstGregorian.date(
                byAdding: .month, value: -3, to: now
            ) ?? now.addingTimeInterval(-90 * 24 * 60 * 60)
        case .custom:
            return nil
        }
        return (fromDate, toDate)
    }
}
