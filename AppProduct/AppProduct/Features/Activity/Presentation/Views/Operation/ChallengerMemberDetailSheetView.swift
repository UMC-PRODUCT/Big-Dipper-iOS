//
//  ChallengerMemberDetailSheetView.swift
//  AppProduct
//
//  Created by 김미주 on 2/5/26.
//

import SwiftUI

/// 챌린저 멤버 상세 정보를 표시하는 바텀 시트 뷰
///
/// 프로필과 기수별 상벌점 요약을 표시합니다.
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
        static let profileSize: CGSize = .init(width: 60, height: 60)
        static let partTagOpacity: Double = 0.14
        static let partStrokeOpacity: Double = 0.4
        static let partStrokeWidth: CGFloat = 1
        static let pointIconSize: CGFloat = 14
    }

    // MARK: - Computed Property

    private var currentGeneration: String {
        if hasMultipleGenerations,
           let lastGisu = uniqueGenerationPoints.map(\.gisu).max() {
            return "\(lastGisu)기"
        }
        let gens = member.generation
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return gens.last ?? member.generation
    }

    private var hasMultipleGenerations: Bool {
        uniqueGenerationPoints.count > 1
    }

    private var uniqueGenerationPoints: [GenerationPointSummary] {
        var seen = Set<Int>()
        return member.generationPoints.filter { seen.insert($0.gisu).inserted }
    }

    private var selectedSummary: GenerationPointSummary? {
        member.generationPoints.first { $0.gisu == selectedGisu }
    }

    private var displayRewardPoints: Double {
        selectedSummary?.reward ?? member.rewardPoints
    }

    private var displayPenaltyPoints: Double {
        selectedSummary?.penalty ?? member.penalty
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
            memberInfoView
            summaryCardView
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.top, DefaultSpacing.spacing8)
        .padding(.bottom, DefaultSpacing.spacing32)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
    }

    // MARK: - SubView

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

    private var schoolTag: some View {
        Text(member.school)
            .appFont(.callout, color: .grey700)
            .padding(Constants.tagPadding)
            .background(.regularMaterial, in: Capsule())
    }

    private var summaryCardView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            // 활동 기수
            HStack {
                Text("활동 기수")
                    .appFont(.subheadline, color: .grey700)
                Spacer()
                if hasMultipleGenerations {
                    generationChips
                } else {
                    Text(currentGeneration)
                        .appFont(.subheadlineEmphasis)
                        .contentTransition(.numericText())
                }
            }

            Divider()

            // 상점 · 벌점
            HStack(spacing: .zero) {
                pointColumn(
                    icon: "plus.circle.fill",
                    iconColor: .green,
                    label: "상점",
                    value: displayRewardPoints,
                    valueColor: .green
                )

                Divider()
                    .frame(height: 44)

                pointColumn(
                    icon: "minus.circle.fill",
                    iconColor: .red,
                    label: "벌점",
                    value: displayPenaltyPoints,
                    valueColor: .red
                )
            }
        }
        .padding(DefaultSpacing.spacing16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
        )
        .animation(.smooth(duration: 0.3), value: selectedGisu)
    }

    private var generationChips: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            ForEach(uniqueGenerationPoints) { summary in
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedGisu = summary.gisu
                    }
                } label: {
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
                }
                .accessibilityLabel("\(summary.gisu)기 선택")
            }
        }
    }

    // MARK: - Function

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
