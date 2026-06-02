//
//  AttendancePolicyDisplaySection.swift
//  AppProduct
//
//  Created by euijjang97 on 5/7/26.
//

import SwiftUI

// MARK: - AttendancePolicyDisplaySection

/// 일정 상세 화면에서 출석 정책 시각을 read-only 로 표시하는 섹션 컴포넌트
///
/// - 체크인 시작(`checkInStartAt`) → 정시 종료(`onTimeEndAt`) → 지각 종료(`lateEndAt`) 순서의
///   3개 임계값을 시간 흐름대로 **가로 3분할** 카드에 배치합니다. (세로 나열 대비 화면 점유 약 60% 절감)
/// - 컬럼은 항상 균등 너비이므로 세 시각이 같거나 역전되거나 간격이 짧아도 레이아웃이 깨지지 않습니다.
/// - 비대면 / 출석 비필수 일정은 `AttendancePolicy` 자체가 `nil` 이므로 호출 측에서 노출을 제어합니다.
/// - Container-Presenter 패턴(`Equatable`)으로 불필요한 리렌더링을 방지합니다.
struct AttendancePolicyDisplaySection: View, Equatable {

    // MARK: - Property

    let policy: AttendancePolicy

    private enum Constants {
        static let title: String = "출석 정책"
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.policy == rhs.policy
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(Constants.title)
                .appFont(.title2Emphasis, color: .black)

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
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(Color.white)
            .glass()
        }
    }

    // MARK: - Column

    private func policyColumn(role: Role, date: Date) -> some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            policyIcon(systemName: role.iconName, tintColor: role.tintColor)

            VStack(spacing: DefaultSpacing.spacing4) {
                Text(timeText(for: date))
                    .appFont(.calloutEmphasis)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(role.label)
                    .appFont(.footnote)
                    .foregroundStyle(.grey500)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
            .background(tintColor.opacity(0.4), in: .circle)
    }

    // MARK: - Role

    /// 출석 정책 3개 임계값의 표시 메타데이터 (아이콘 / 라벨 / 색상 시맨틱)
    ///
    /// 색상: green(체크인 가능) → orange(정시 마감) → red(지각 마감) 으로 시간 흐름의 위험도를 표현합니다.
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

        /// 표시 라벨. 입력 폼(`AttendancePolicyTimeSection`) 및 도메인(`lateEndAt`)과 용어를 통일합니다.
        var label: String {
            switch self {
            case .checkIn: "체크인 시작"
            case .onTime: "정시 종료"
            case .late: "지각 종료"
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

    // MARK: - Helper

    /// 정책 시각을 KST 기준 표시 문자열로 변환합니다.
    ///
    /// 기준점(`checkInStartAt`)과 같은 날이면 `"HH:mm"`, 다른 날(자정을 넘는 정책 등)이면 `"M/d HH:mm"`.
    private func timeText(for date: Date) -> String {
        Self.kstTimeText(for: date, anchor: policy.checkInStartAt)
    }

    private static func kstTimeText(for date: Date, anchor: Date) -> String {
        if Calendar.kstGregorian.isDate(date, inSameDayAs: anchor) {
            return Self.kstHourMinuteFormatter.string(from: date)
        }
        return Self.kstDateTimeFormatter.string(from: date)
    }

    private func accessibilityLabel(for role: String, date: Date) -> String {
        let timeStr = AttendancePolicyDisplaySection.kstAccessibilityFormatter.string(from: date)
        return "\(role): \(timeStr)"
    }

    // MARK: - Formatters

    private static let kstHourMinuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let kstDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    private static let kstAccessibilityFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        f.dateFormat = "HH시 mm분"
        return f
    }()
}

// MARK: - Preview

#if DEBUG
#Preview {
    let now = Date()
    let policy = AttendancePolicy(
        checkInStartAt: now.addingTimeInterval(-3600),
        onTimeEndAt: now.addingTimeInterval(0),
        lateEndAt: now.addingTimeInterval(1800)
    )
    return ScrollView {
        AttendancePolicyDisplaySection(policy: policy)
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
}
#endif
