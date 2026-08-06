//
//  AttendancePolicyDisplay.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

// MARK: - AttendancePolicyRole

/// 출석 정책 3개 시각의 표시 메타데이터
///
/// 출석 체크 화면의 정책 팝오버(``ChallengerAttendanceView``)와 출석 이력 카드
/// (``ChallengerMyAttendanceCard``)가 같은 아이콘·라벨·색상을 쓰도록 한 곳에 모읍니다.
enum AttendancePolicyRole {
    case checkIn
    case onTime
    case late

    var iconName: String {
        switch self {
        case .checkIn: "door.right.hand.open"
        case .onTime: "clock.badge.checkmark"
        case .late: "xmark.circle"
        }
    }

    var label: String {
        switch self {
        case .checkIn: "출석 시작"
        case .onTime: "출석 인정 마감"
        case .late: "지각 인정 마감"
        }
    }

    var tintColor: Color {
        switch self {
        case .checkIn: .green500
        case .onTime: .orange500
        case .late: .red500
        }
    }
}

// MARK: - Policy Time Formatting

extension Date {
    /// 출석 정책 시각 표시 문자열
    ///
    /// 기준점(보통 `checkInStartAt`)과 같은 날이면 `"HH:mm"`, 자정을 넘긴 정책처럼
    /// 다른 날이면 `"M/d HH:mm"` 로 날짜를 함께 보여줍니다.
    ///
    /// - Note: 레거시는 팝오버와 이력 카드가 같은 값을 서로 다른 포맷으로 보여줘 이식하면서
    ///   하나로 통일했습니다.
    /// - Important: 날짜 부분에 공용 `toMonthDay()` 를 쓰면 안 됩니다. 그 헬퍼는 타임존을
    ///   지정하지 않아 **기기 타임존**으로 포맷하는데, 같은 날 판정(`isSameDay`)과 시각
    ///   부분(`toHourMinutes()`)은 KST 고정입니다. 섞으면 KST 가 아닌 기기에서 "날짜는
    ///   로컬, 시각은 KST" 인 어긋난 문자열이 나옵니다 — 예를 들어 KST 5/8 00:30 마감이
    ///   미국 기기에서 "5/7 00:30" 으로 보여 마감이 하루 앞당겨진 것처럼 읽힙니다.
    func attendancePolicyText(anchoredAt anchor: Date) -> String {
        isSameDay(anchor)
            ? toHourMinutes()
            : "\(Self.kstMonthDayFormatter.string(from: self)) \(toHourMinutes())"
    }

    /// KST 고정 "M/d" 포맷터
    ///
    /// 로케일별 표기 흔들림(ko_KR 은 "05. 08." 처럼 점·공백을 붙임)을 막기 위해
    /// `en_US_POSIX` 로 고정합니다.
    private static let kstMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .kst
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
