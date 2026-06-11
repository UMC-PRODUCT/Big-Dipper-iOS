//
//  ChallengerMyAttendanceCard.swift
//  AppProduct
//
//  Created by 김미주 on 1/9/26.
//

import SwiftUI

// MARK: - ChallengerMyAttendanceCard

/// 나의 출석 현황 카드
///
/// 접힌 상태에서는 제목/일시/상태 뱃지만 표시하고,
/// 탭하여 펼치면 장소(또는 비대면)와 출석 정책 시각을 표시합니다.
/// 펼치기 인터랙션은 출석 가능한 세션 카드(``ChallengerSessionCard``)와 동일한 문법을 따릅니다.
struct ChallengerMyAttendanceCard: View {
    // MARK: - Property

    private let model: MyAttendanceItemModel
    private let isExpanded: Bool
    private let onTap: () -> Void

    // MARK: - Init

    init(
        model: MyAttendanceItemModel,
        isExpanded: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.model = model
        self.isExpanded = isExpanded
        self.onTap = onTap
    }

    // MARK: - Body

    var body: some View {
        MyAttendanceItemPresenter(
            model: model,
            isExpanded: isExpanded,
            onTap: onTap
        )
        .equatable()
    }
}

// MARK: - Presenter

private struct MyAttendanceItemPresenter: View, Equatable {
    let model: MyAttendanceItemModel
    let isExpanded: Bool
    var onTap: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model && lhs.isExpanded == rhs.isExpanded
    }

    private enum Constants {
        static let cardSpacing: CGFloat = 12
        static let contentSectionSpacing: CGFloat = 4
        static let statusRadius: CGFloat = 8
        static let infoIconSpacing: CGFloat = 4
        static let policyCornerRadius: CGFloat = 12
        static let policyColumnSpacing: CGFloat = 2
        static let policyTextScaleFactor: CGFloat = 0.8
    }

    /// 펼쳤을 때 보여줄 추가 정보(정책/장소/비대면)가 있는지
    private var hasExpandableContent: Bool {
        model.attendancePolicy != nil || model.isOnline || model.locationName != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            header

            if isExpanded {
                expandedSection
                    .transition(.asymmetric(
                        insertion: .scale(scale: DefaultConstant.transitionScale).combined(with: .opacity),
                        removal: .scale(scale: DefaultConstant.transitionScale).combined(with: .opacity)))
            }
        }
        .padding(DefaultConstant.defaultListPadding)
        .background(.white)
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasExpandableContent else { return }
            onTap()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Constants.cardSpacing) {
            CardIconImage(
                image: model.category.symbol,
                color: model.category.color,
                isLoading: .constant(false))

            contentSection
                .frame(maxWidth: .infinity, alignment: .leading)

            statusBadge

            if hasExpandableContent {
                Image(systemName: isExpanded
                      ? DefaultConstant.chevronUpImage
                      : DefaultConstant.chevronDownImage)
                    .foregroundStyle(.gray)
            }
        }
    }

    private var contentSection: some View {
        VStack(
            alignment: .leading,
            spacing: Constants.contentSectionSpacing
        ) {
            Text(model.title)
                .appFont(.calloutEmphasis, color: .black)
                .lineLimit(2)

            infoRow(systemName: "clock", text: "\(model.dateText) · \(model.timeRange)")
        }
    }

    private func infoRow(systemName: String, text: String) -> some View {
        HStack(spacing: Constants.infoIconSpacing) {
            Image(systemName: systemName)
                .font(.caption)
            Text(text)
                .lineLimit(1)
        }
        .appFont(.footnote, color: .grey500)
    }

    private var statusBadge: some View {
        Text(model.status.text)
            .appFont(.caption1Emphasis, color: model.status.fontColor)
            .padding(DefaultConstant.badgePadding)
            .background(
                model.status.backgroundColor,
                in: RoundedRectangle(cornerRadius: Constants.statusRadius)
            )
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
    }

    // MARK: - Expanded Section

    /// 일정 등록 시 입력한 출석 정보 (장소/비대면 + 출석 정책 시각)
    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            if model.isOnline {
                infoRow(systemName: "video", text: "비대면 진행")
            } else if let locationName = model.locationName {
                infoRow(systemName: "mappin.and.ellipse", text: locationName)
            }

            if let policy = model.attendancePolicy {
                policySummary(policy)
            }
        }
    }

    // MARK: - Policy Summary

    /// 일정 등록 시 입력한 출석 정책 3개 시각 요약
    ///
    /// 일정 상세의 ``AttendancePolicyDisplaySection`` 과 용어·아이콘·색상 시맨틱을 통일한 축소판입니다.
    private func policySummary(_ policy: AttendancePolicy) -> some View {
        HStack(spacing: .zero) {
            policyColumn(role: .checkIn, date: policy.checkInStartAt, anchor: policy.checkInStartAt)

            Divider()

            policyColumn(role: .onTime, date: policy.onTimeEndAt, anchor: policy.checkInStartAt)

            Divider()

            policyColumn(role: .late, date: policy.lateEndAt, anchor: policy.checkInStartAt)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.grey100,
            in: RoundedRectangle(cornerRadius: Constants.policyCornerRadius)
        )
    }

    private func policyColumn(role: PolicyRole, date: Date, anchor: Date) -> some View {
        VStack(spacing: Constants.policyColumnSpacing) {
            HStack(spacing: Constants.infoIconSpacing) {
                Image(systemName: role.iconName)
                    .font(.caption2)
                    .foregroundStyle(role.tintColor)
                Text(role.label)
                    .appFont(.caption2, color: .grey500)
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.policyTextScaleFactor)
            }

            Text(Self.policyTimeText(for: date, anchor: anchor))
                .appFont(.footnoteEmphasis, color: .grey700)
                .lineLimit(1)
                .minimumScaleFactor(Constants.policyTextScaleFactor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DefaultSpacing.spacing8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(role.label): \(Self.policyTimeText(for: date, anchor: anchor))")
    }

    // MARK: - PolicyRole

    /// 출석 정책 컬럼 표시 메타데이터
    ///
    /// 아이콘/라벨/색상은 일정 상세 ``AttendancePolicyDisplaySection`` 의 Role 과 동일하게 유지합니다.
    private enum PolicyRole {
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
    private static func policyTimeText(for date: Date, anchor: Date) -> String {
        if Calendar.kstGregorian.isDate(date, inSameDayAs: anchor) {
            return kstHourMinuteFormatter.string(from: date)
        }
        return kstDateTimeFormatter.string(from: date)
    }

    // MARK: - Formatters

    private static let kstHourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .kst
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let kstDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .kst
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}

#if DEBUG
// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    let now = Date()
    let model = MyAttendanceItemModel(
        week: 1,
        title: "정기 세션",
        startTime: now,
        endTime: now.addingTimeInterval(4 * 3600),
        status: .present,
        category: .general,
        attendancePolicy: AttendancePolicy(
            checkInStartAt: now.addingTimeInterval(-10 * 60),
            onTimeEndAt: now.addingTimeInterval(10 * 60),
            lateEndAt: now.addingTimeInterval(60 * 60)
        ),
        locationName: "공학관 6층 세미나실"
    )

    VStack(spacing: 8) {
        ChallengerMyAttendanceCard(model: model)

        ChallengerMyAttendanceCard(model: model, isExpanded: true)
    }
    .frame(height: 400)
    .background(Color.grey100)
}
#endif
