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
/// - 체크인 시작(`checkInStartAt`), 정시 종료(`onTimeEndAt`), 결석 시작(`lateEndAt`) 3개 행을
///   `Divider()` 로 구분하여 세로 카드로 배치합니다.
/// - 비대면 / 출석 비필수 일정은 `AttendancePolicy` 자체가 `nil` 이므로 호출 측에서 노출을 제어합니다.
/// - Container-Presenter 패턴(`Equatable`)으로 불필요한 리렌더링을 방지합니다.
struct AttendancePolicyDisplaySection: View, Equatable {

    // MARK: - Property

    let policy: AttendancePolicy

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.policy == rhs.policy
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text("출석 정책")
                .appFont(.title3Emphasis, color: .black)

            policyCard
        }
    }

    // MARK: - Card

    private var policyCard: some View {
        VStack(spacing: .zero) {
            policyRow(
                iconName: "door.right.hand.open",
                label: "체크인 시작",
                tintColor: .green,
                date: policy.checkInStartAt
            )
            .accessibilityLabel(accessibilityLabel(for: "체크인 시작", date: policy.checkInStartAt))

            Divider()

            policyRow(
                iconName: "clock.badge.checkmark",
                label: "정시 종료",
                tintColor: .orange,
                date: policy.onTimeEndAt
            )
            .accessibilityLabel(accessibilityLabel(for: "정시 종료", date: policy.onTimeEndAt))

            Divider()

            policyRow(
                iconName: "xmark.circle",
                label: "결석 시작",
                tintColor: .red,
                date: policy.lateEndAt
            )
            .accessibilityLabel(accessibilityLabel(for: "결석 시작", date: policy.lateEndAt))
        }
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(Color.white)
            .glass()
        }
    }

    // MARK: - Row

    private func policyRow(
        iconName: String,
        label: String,
        tintColor: Color,
        date: Date
    ) -> some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            policyIcon(systemName: iconName, tintColor: tintColor)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(AttendancePolicyDisplaySection.kstTimeText(for: date, anchor: policy.checkInStartAt))
                    .appFont(.calloutEmphasis)
                    .foregroundStyle(.black)

                Text(label)
                    .appFont(.footnote)
                    .foregroundStyle(.grey500)
            }

            Spacer()
        }
        .padding(DefaultSpacing.spacing16)
    }

    private func policyIcon(systemName: String, tintColor: Color) -> some View {
        Image(systemName: systemName)
            .foregroundStyle(tintColor)
            .font(.system(size: 16))
            .padding()
            .background(tintColor.opacity(0.4), in: .circle)
            .glassEffect(.clear, in: .circle)
    }

    // MARK: - Helper

    /// 정책 시각을 KST 기준으로 표시합니다.
    ///
    /// 같은 날이면 `"HH:mm"`, 다른 날(자정을 넘는 정책 등)이면 `"M/d HH:mm"`.
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
