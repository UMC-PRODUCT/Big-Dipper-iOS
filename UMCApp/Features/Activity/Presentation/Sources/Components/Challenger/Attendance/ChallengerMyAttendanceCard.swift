//
//  ChallengerMyAttendanceCard.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

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

/// 카드의 렌더링 담당 (`Equatable` 로 클로저를 비교에서 제외)
private struct MyAttendanceItemPresenter: View, Equatable {
    let model: MyAttendanceItemModel
    let isExpanded: Bool
    var onTap: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model && lhs.isExpanded == rhs.isExpanded
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let cardSpacing: CGFloat = 12
        static let contentSectionSpacing: CGFloat = 4
        static let statusRadius: CGFloat = 8
        static let infoIconSpacing: CGFloat = 4
        static let policyCornerRadius: CGFloat = 12
        static let policyColumnSpacing: CGFloat = 2
        static let policyTextScaleFactor: CGFloat = 0.8
        static let titleLineLimit: Int = 2
    }

    /// 펼쳤을 때 보여줄 추가 정보(정책/장소/비대면)가 있는지
    private var hasExpandableContent: Bool {
        model.attendancePolicy != nil || model.isOnline || model.locationName != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            header

            if isExpanded {
                expandedSection
                    .transition(.asymmetric(
                        insertion: .scale(scale: DefaultConstant.transitionScale)
                            .combined(with: .opacity),
                        removal: .scale(scale: DefaultConstant.transitionScale)
                            .combined(with: .opacity)
                    ))
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
                isLoading: .constant(false)
            )

            contentSection
                .frame(maxWidth: .infinity, alignment: .leading)

            statusBadge

            if hasExpandableContent {
                Image(
                    systemName: isExpanded
                        ? DefaultConstant.chevronUpImage
                        : DefaultConstant.chevronDownImage
                )
                .foregroundStyle(Color.grey400)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Constants.contentSectionSpacing) {
            Text(model.title)
                .appFont(.callout, weight: .semibold, color: .grey900)
                .lineLimit(Constants.titleLineLimit)

            // 날짜+시간을 한 줄에 합치면 뱃지/셰브론과 폭을 경쟁해 잘리므로 두 줄로 분리
            infoRow(systemName: "calendar", text: model.dateText)
            infoRow(systemName: "clock", text: model.timeRange)
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
            .appFont(.caption1, weight: .semibold, color: model.status.fontColor)
            .padding(DefaultConstant.badgePadding)
            .background(
                model.status.backgroundColor,
                in: RoundedRectangle(cornerRadius: Constants.statusRadius)
            )
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
            )
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
    /// 출석 체크 화면의 정책 팝오버와 용어·아이콘·색상 시맨틱을 통일한 축소판입니다.
    private func policySummary(_ policy: ScheduleAttendancePolicy) -> some View {
        HStack(spacing: .zero) {
            policyColumn(
                role: .checkIn,
                date: policy.checkInStartAt,
                anchor: policy.checkInStartAt
            )

            Divider()

            policyColumn(
                role: .onTime,
                date: policy.onTimeEndAt,
                anchor: policy.checkInStartAt
            )

            Divider()

            policyColumn(
                role: .late,
                date: policy.lateEndAt,
                anchor: policy.checkInStartAt
            )
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.grey100,
            in: RoundedRectangle(cornerRadius: Constants.policyCornerRadius)
        )
    }

    private func policyColumn(
        role: AttendancePolicyRole,
        date: Date,
        anchor: Date
    ) -> some View {
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

            Text(date.attendancePolicyText(anchoredAt: anchor))
                .appFont(.footnote, weight: .semibold, color: .grey700)
                .lineLimit(1)
                .minimumScaleFactor(Constants.policyTextScaleFactor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DefaultSpacing.spacing8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(role.label): \(date.attendancePolicyText(anchoredAt: anchor))"
        )
    }
}

#if DEBUG
// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    let model = AttendancePreviewData.myAttendanceItem()

    ZStack {
        Color.grey100.frame(height: 400)

        VStack(spacing: DefaultSpacing.spacing8) {
            ChallengerMyAttendanceCard(model: model)
            ChallengerMyAttendanceCard(model: model, isExpanded: true)
        }
        .padding()
    }
}
#endif
