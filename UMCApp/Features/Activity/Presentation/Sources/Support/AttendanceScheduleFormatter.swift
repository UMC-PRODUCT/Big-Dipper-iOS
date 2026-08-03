//
//  AttendanceScheduleFormatter.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import Foundation
import UMCFoundation

/// 운영진 출석 화면의 일정 표시 문자열 생성기.
///
/// 목록 카드와 상세 헤더가 같은 규칙(KST 기준 표기, 비정상 범위 폴백, 출석률 표기)을
/// 공유하도록 한곳에 모읍니다. 레거시는 두 화면이 각자 `dateRangeText`/`rateText` 를
/// 중복 보유해 포맷만 다른 같은 분기가 두 벌 있었습니다.
///
/// `DateFormatter` 는 생성 비용이 크므로 `static let` 으로 프로세스당 1회만 만듭니다.
enum AttendanceScheduleFormatter {

    /// 일시 범위 표기 스타일
    enum DateRangeStyle {
        /// 목록 카드용 — "6월 3일 (화) 19:00"
        case list
        /// 상세 헤더용 — "2026.6.3 (화) 19:00"
        case detail
    }

    // MARK: - Date Range

    /// "{시작 일시} ~ {종료 시각}" 문자열.
    ///
    /// - Note: 시작이 종료보다 늦은 비정상 범위(서버 데이터 오류)는 "~ 종료" 를 붙이면
    ///   거꾸로 읽히므로 시작 일시만 표기합니다.
    static func dateRangeText(
        from startsAt: Date,
        to endsAt: Date,
        style: DateRangeStyle
    ) -> String {
        let startFormatter = startFormatter(for: style)
        guard startsAt <= endsAt else {
            return startFormatter.string(from: startsAt)
        }
        let start = startFormatter.string(from: startsAt)
        let end = hourMinuteFormatter.string(from: endsAt)
        return "\(start) ~ \(end)"
    }

    // MARK: - Attendance Rate

    /// 출석률 백분율 문자열. 참여자가 없으면 분모가 0이라 "—" 로 표기합니다.
    static func attendanceRateText(rate: Double, totalCount: Int) -> String {
        guard totalCount > 0 else { return "—" }
        let percent = Int((rate * 100).rounded())
        return "\(percent)%"
    }

    // MARK: - Formatters

    private static func startFormatter(for style: DateRangeStyle) -> DateFormatter {
        switch style {
        case .list:   return listStartFormatter
        case .detail: return detailStartFormatter
        }
    }

    private static let listStartFormatter: DateFormatter = {
        makeFormatter(dateFormat: "M월 d일 (E) HH:mm")
    }()

    private static let detailStartFormatter: DateFormatter = {
        makeFormatter(dateFormat: "yyyy.M.d (E) HH:mm")
    }()

    private static let hourMinuteFormatter: DateFormatter = {
        makeFormatter(dateFormat: "HH:mm")
    }()

    private static func makeFormatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .kst
        return formatter
    }
}
