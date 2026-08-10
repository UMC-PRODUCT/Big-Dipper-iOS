//
//  AttendancePolicyDisplaySection.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/6/26.
//

import CoreDesignSystem
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

/// 일정 상세 화면에서 출석 정책 시각을 read-only 로 표시하는 섹션.
///
/// 출석 시작(`checkInStartAt`) → 출석 인정 마감(`onTimeEndAt`) → 지각 인정 마감(`lateEndAt`)
/// 3개 임계값을 시간 흐름대로 가로 3분할 카드에 배치한다. 컬럼 너비가 항상 균등하므로 세 시각이
/// 같거나 역전돼도 레이아웃이 깨지지 않는다.
///
/// 출석 비필수 일정은 정책 자체가 `nil` 이므로 노출 제어는 호출부가 맡는다.
struct AttendancePolicyDisplaySection: View, Equatable {

    // MARK: - Property

    let policy: ScheduleAttendancePolicy

    fileprivate enum Constants {
        static let title: String = "출석 정책"
        static let minimumScaleFactor: CGFloat = 0.8
        static let iconBackgroundOpacity: CGFloat = 0.4
        static let lineLimit: Int = 1
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.policy == rhs.policy
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(Constants.title)
                .appFont(.title2, weight: .semibold, color: .grey900)

            policyCard
        }
    }

    // MARK: - Card

    private var policyCard: some View {
        HStack(spacing: .zero) {
            policyColumn(role: .checkIn, date: policy.checkInStartAt)

            Divider()

            policyColumn(role: .onTime, date: policy.onTimeEndAt)

            Divider()

            policyColumn(role: .late, date: policy.lateEndAt)
        }
        .frame(maxWidth: .infinity)
        .glassEffect(
            .regular,
            in: .rect(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    // MARK: - Column

    private func policyColumn(role: Role, date: Date) -> some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            policyIcon(systemName: role.iconName, tintColor: role.tintColor)

            VStack(spacing: DefaultSpacing.spacing4) {
                Text(timeText(for: date))
                    .appFont(.callout, weight: .semibold, color: .grey900)
                    .lineLimit(Constants.lineLimit)
                    .minimumScaleFactor(Constants.minimumScaleFactor)

                Text(role.label)
                    .appFont(.footnote, color: .grey500)
                    .lineLimit(Constants.lineLimit)
                    .minimumScaleFactor(Constants.minimumScaleFactor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DefaultSpacing.spacing16)
        .padding(.horizontal, DefaultSpacing.spacing8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: role.label, date: date))
    }

    private func policyIcon(systemName: String, tintColor: Color) -> some View {
        Image(systemName: systemName)
            .foregroundStyle(tintColor)
            .imageScale(.medium)
            .padding(DefaultSpacing.spacing12)
            .background(tintColor.opacity(Constants.iconBackgroundOpacity), in: .circle)
    }

    // MARK: - Role

    /// 출석 정책 3개 임계값의 표시 메타데이터 (아이콘 / 라벨 / 색상 시맨틱).
    ///
    /// 색상은 green(출석 가능) → orange(출석 인정 마감) → red(지각 인정 마감) 순으로 시간 흐름의
    /// 위험도를 표현한다.
    private enum Role {
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

        /// 표시 라벨. 도메인(`lateEndAt`)과 용어를 통일한다.
        var label: String {
            switch self {
            case .checkIn: "출석 시작"
            case .onTime: "출석 인정 마감"
            case .late: "지각 인정 마감"
            }
        }

        var tintColor: Color {
            switch self {
            case .checkIn: .green
            case .onTime: .orange
            case .late: .red
            }
        }
    }

    // MARK: - Function

    /// 정책 시각을 KST 기준 표시 문자열로 변환한다.
    ///
    /// 기준점(`checkInStartAt`)과 같은 날이면 시각만, 자정을 넘는 정책처럼 다른 날이면 날짜까지
    /// 함께 보여준다.
    private func timeText(for date: Date) -> String {
        if Calendar.kstGregorian.isDate(date, inSameDayAs: policy.checkInStartAt) {
            return date.toHourMinutes()
        }
        return date.toMonthDayWeekDayWithTime()
    }

    /// VoiceOver 는 `"14:30"` 을 시각으로 읽어 주지 않아, 표시용과 별도로 문장형 시각을 만든다.
    private func accessibilityLabel(for role: String, date: Date) -> String {
        "\(role): \(Self.kstSpokenTimeFormatter.string(from: date))"
    }

    // MARK: - Formatter

    private static let kstSpokenTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .kst
        formatter.dateFormat = "HH시 mm분"
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
#Preview {
    let now = Date()
    ScrollView {
        AttendancePolicyDisplaySection(
            policy: ScheduleAttendancePolicy(
                checkInStartAt: now.addingTimeInterval(-3600),
                onTimeEndAt: now,
                lateEndAt: now.addingTimeInterval(1800)
            )
        )
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
}
#endif
