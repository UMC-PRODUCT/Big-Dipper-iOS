//
//  ChallengerMemberDetailSheetView.swift
//  AppProduct
//
//  Created by 김미주 on 2/5/26.
//

import SwiftUI

/// 챌린저 멤버 상세 정보를 표시하는 바텀 시트 뷰
///
/// 프로필, 기수별 상벌점 요약, 출석/활동 기록을 표시합니다.
/// 복수 기수 사용자의 경우 `Picker`를 통해 기수를 전환할 수 있습니다.
struct ChallengerMemberDetailSheetView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    var member: MemberManagementItem
    @State private var selectedGisu: Int

    init(member: MemberManagementItem) {
        self.member = member
        _selectedGisu = State(
            initialValue: member.generationPoints.map(\.gisu).max() ?? 0
        )
    }

    private enum Constants {
        static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
        static let boxPadding: EdgeInsets = .init(top: 12, leading: 0, bottom: 12, trailing: 0)
        static let listPadding: EdgeInsets = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        static let profileSize: CGSize = .init(width: 60, height: 60)

        static let baseHeight: CGFloat = 360
        static let emptyRecordHeight: CGFloat = 150
        static let sheetHeight: CGFloat = 680
        static let recordRowMinHeight: CGFloat = 44

        static let summaryRowVerticalPadding: CGFloat = 12
        static let partTagOpacity: Double = 0.14
        static let partStrokeOpacity: Double = 0.4
        static let partStrokeWidth: CGFloat = 1
        static let pointIconSize: CGFloat = 14
    }

    // MARK: - Computed Property

    /// 단일 기수 사용자의 기수 텍스트 (예: "9기")
    private var currentGeneration: String {
        if hasMultipleGenerations,
           let lastGisu = member.generationPoints.map(\.gisu).max() {
            return "\(lastGisu)기"
        }
        let gens = member.generation
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return gens.last ?? member.generation
    }

    /// 복수 기수 보유 여부
    private var hasMultipleGenerations: Bool {
        member.generationPoints.count > 1
    }

    /// 현재 선택된 기수의 포인트 요약 데이터
    private var selectedSummary: GenerationPointSummary? {
        member.generationPoints.first { $0.gisu == selectedGisu }
    }

    /// 표시할 상점 (선택된 기수 우선, 없으면 전체 합산)
    private var displayRewardPoints: Double {
        selectedSummary?.reward ?? member.rewardPoints
    }

    /// 표시할 벌점 (선택된 기수 우선, 없으면 전체 합산)
    private var displayPenaltyPoints: Double {
        selectedSummary?.penalty ?? member.penalty
    }


    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing32) {
                    memberInfoView
                    summaryCardView
                    recordView
                }
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .safeAreaPadding(.bottom, DefaultConstant.defaultSafeBottom)
            }
            .scrollContentBackground(.hidden)
            .presentationDetents([.height(Constants.sheetHeight), .large])
        }
    }

    // MARK: - SubView

    /// 프로필 이미지, 닉네임/이름, 파트·학교·운영진 배지를 표시
    private var memberInfoView: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(urlString: member.profile ?? "", size: Constants.profileSize)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                Text("\(member.nickname)/\(member.name)")
                    .appFont(.bodyEmphasis)

                HStack(spacing: DefaultSpacing.spacing8) {
                    partTag
                    schoolTag
                    if member.managementTeam != .challenger {
                        ManagementTeamBadgePresenter(managementTeam: member.managementTeam)
                    }
                }
            }
        }
    }

    /// 파트 태그 (색상 배경 + 테두리)
    private var partTag: some View {
        Text(member.part.name)
            .appFont(.callout, color: member.part.color)
            .padding(Constants.tagPadding)
            .background(
                member.part.color.opacity(Constants.partTagOpacity),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        member.part.color.opacity(Constants.partStrokeOpacity),
                        lineWidth: Constants.partStrokeWidth
                    )
            }
    }

    /// 학교 태그
    private var schoolTag: some View {
        Text(member.school)
            .appFont(.callout, color: .black)
            .padding(Constants.tagPadding)
            .background(.white, in: Capsule())
    }

    /// 활동 기수 · 상점 · 벌점 요약 카드
    private var summaryCardView: some View {
        VStack(spacing: .zero) {
            summaryRow(title: "활동 기수") {
                if hasMultipleGenerations {
                    generationChips
                } else {
                    Text(currentGeneration)
                        .appFont(.subheadlineEmphasis)
                        .contentTransition(.numericText())
                }
            }

            Divider()

            HStack(spacing: .zero) {
                pointColumn(
                    icon: "plus.circle.fill",
                    iconColor: .green,
                    label: "상점",
                    value: displayRewardPoints,
                    valueColor: .green
                )

                Divider()
                    .frame(height: 48)

                pointColumn(
                    icon: "minus.circle.fill",
                    iconColor: .red,
                    label: "벌점",
                    value: displayPenaltyPoints,
                    valueColor: .red
                )
            }
            .padding(.vertical, Constants.summaryRowVerticalPadding)
        }
        .padding(.horizontal, Constants.listPadding.leading)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
        .animation(.smooth(duration: 0.3), value: selectedGisu)
    }

    /// 복수 기수 전환 인라인 칩 셀렉터
    private var generationChips: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            ForEach(member.generationPoints) { summary in
                Text("\(summary.gisu)기")
                    .appFont(
                        selectedGisu == summary.gisu
                            ? .subheadlineEmphasis : .subheadline,
                        color: selectedGisu == summary.gisu
                            ? .white : .grey700
                    )
                    .padding(Constants.tagPadding)
                    .background(
                        selectedGisu == summary.gisu
                            ? Color.accentColor : Color.grey200,
                        in: Capsule()
                    )
                    .onTapGesture {
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedGisu = summary.gisu
                        }
                    }
            }
        }
    }

    /// 출석/활동 기록 섹션
    private var recordView: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Label(
                "출석/활동 기록",
                systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
            )
            .appFont(.title3Emphasis)

            attendanceRecordListView
        }
    }

    /// 출석 이력 리스트 (기록 없으면 빈 상태 카드)
    private var attendanceRecordListView: some View {
        Group {
            if member.attendanceRecords.isEmpty {
                attendanceEmptyView
            } else {
                VStack(spacing: .zero) {
                    ForEach(Array(member.attendanceRecords.enumerated()), id: \.element.id) { index, record in
                        attendanceRecordRow(record: record)
                        if index < member.attendanceRecords.count - 1 {
                            Divider()
                                .padding(.horizontal, Constants.listPadding.leading)
                        }
                    }
                }
                .background(
                    .white,
                    in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                )
                .glass()
            }
        }
    }

    /// 출석 이력이 없을 때 빈 상태 카드
    private var attendanceEmptyView: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "calendar.badge.checkmark")
                .appFont(.title1, color: .grey500)
            Text("출석 이력이 없습니다")
                .appFont(.subheadlineEmphasis, color: .grey500)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.emptyRecordHeight)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }

    /// 출석 이력 개별 행
    private func attendanceRecordRow(record: MemberAttendanceRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text("\(record.week)주차")
                    .appFont(.footnote, color: .grey500)
                Text(record.sessionTitle)
                    .appFont(.subheadlineEmphasis)
                    .lineLimit(1)
            }
            Spacer()
            attendanceStatusBadge(status: record.status)
        }
        .padding(Constants.listPadding)
        .frame(minHeight: Constants.recordRowMinHeight)
    }

    /// 출석 상태 배지
    private func attendanceStatusBadge(status: AttendanceStatus) -> some View {
        Text(status.displayText)
            .appFont(.caption1Emphasis, color: .white)
            .padding(.horizontal, DefaultSpacing.spacing8)
            .padding(.vertical, DefaultSpacing.spacing4)
            .background(status.backgroundColor, in: Capsule())
    }

    // MARK: - Function

    /// 상벌점 2열 레이아웃의 개별 컬럼
    private func pointColumn(
        icon: String,
        iconColor: Color,
        label: String,
        value: Double,
        valueColor: Color
    ) -> some View {
        VStack(spacing: DefaultSpacing.spacing4) {
            HStack(spacing: DefaultSpacing.spacing4) {
                Image(systemName: icon)
                    .font(.system(size: Constants.pointIconSize))
                    .foregroundStyle(iconColor)
                Text(label)
                    .appFont(.footnote, color: .grey700)
            }

            Text(String(format: "%.0f", value))
                .appFont(.calloutEmphasis, color: valueColor)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    /// 요약 카드의 개별 행 (타이틀 + 우측 값)
    private func summaryRow<Content: View>(
        title: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .appFont(.subheadline, color: .grey700)
            Spacer()
            value()
        }
        .padding(.vertical, Constants.summaryRowVerticalPadding)
    }

}

// MARK: - Preview

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            ChallengerMemberDetailSheetView(
                member: .init(
                    profile: nil,
                    name: "김미주",
                    nickname: "마티",
                    generation: "7기, 8기, 9기",
                    school: "덕성여자대학교",
                    position: "Challenger",
                    part: .front(type: .ios),
                    penalty: 2,
                    rewardPoints: 3,
                    badge: false,
                    managementTeam: .schoolPartLeader,
                    attendanceRecords: [],
                    penaltyHistory: [],
                    generationPoints: [
                        GenerationPointSummary(gisu: 7, reward: 1, penalty: 0),
                        GenerationPointSummary(gisu: 8, reward: 2, penalty: 1),
                        GenerationPointSummary(gisu: 9, reward: 0, penalty: 1)
                    ]
                )
            )
        }
}
