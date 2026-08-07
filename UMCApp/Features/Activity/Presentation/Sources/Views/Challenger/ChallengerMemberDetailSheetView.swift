//
//  ChallengerMemberDetailSheetView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 챌린저 멤버 상세 정보를 표시하는 바텀 시트 뷰
///
/// 프로필과 기수별 상벌점 요약을 표시합니다.
/// 복수 기수 사용자의 경우 `Picker`를 통해 기수를 전환할 수 있습니다.
struct ChallengerMemberDetailSheetView: View {

    // MARK: - Property

    let member: MemberManagementItem
    @State private var selectedGisu: Int

    // MARK: - Constants

    private enum Constants {
        static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
        static let profileSize: CGSize = .init(width: 60, height: 60)
        static let partTagOpacity: Double = 0.14
        static let partStrokeOpacity: Double = 0.4
        static let partStrokeWidth: CGFloat = 1
        static let pointIconSize: CGFloat = 14
        static let dividerHeight: CGFloat = 44

        /// Apple HIG 최소 터치 타겟(44pt).
        static let minimumTapTarget: CGFloat = 44

        /// 기수 칩 탭 영역을 44pt 로 넓히면서 활동 기수 행이 약 21pt 높아져,
        /// 기존 280pt 로는 여유가 10pt 남짓만 남는다. 여유를 되돌려 잡은 값.
        static let detentHeight: CGFloat = 300
    }

    // MARK: - Init

    init(member: MemberManagementItem) {
        self.member = member
        _selectedGisu = State(
            initialValue: member.generationPoints.map(\.gisu).max() ?? 0
        )
    }

    // MARK: - Computed Property

    /// 기수가 하나뿐인 멤버의 기수 문자열.
    ///
    /// - Note: 복수 기수 멤버는 ``generationChips`` 로 분기하므로 이 프로퍼티를 읽지 않습니다.
    private var currentGeneration: String {
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
        .presentationDetents([.height(Constants.detentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
    }

    // MARK: - SubView

    private var memberInfoView: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(urlString: member.profile ?? "", size: Constants.profileSize)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                Text("\(member.nickname)/\(member.name)")
                    .appFont(.body, weight: .semibold)

                HStack(spacing: DefaultSpacing.spacing8) {
                    partTag
                    schoolTag
                    if member.managementTeam != .challenger {
                        ManagementTeamBadgePresenter(
                            managementTeam: member.managementTeam
                        )
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
            HStack {
                Text("활동 기수")
                    .appFont(.subheadline, color: .grey700)

                // 복수 기수일 때는 `Spacer` 를 두지 않는다. 칩 스크롤뷰가 남은 폭을
                // 전부 차지해야 기수가 많아도 스크롤로 닿을 수 있고, 칩이 적을 때는
                // `defaultScrollAnchor(.trailing)` 이 우측 정렬을 대신한다.
                if hasMultipleGenerations {
                    generationChips
                } else {
                    Spacer()

                    Text(currentGeneration)
                        .appFont(.subheadline, weight: .semibold)
                        .contentTransition(.numericText())
                }
            }

            Divider()

            HStack(spacing: .zero) {
                pointColumn(
                    icon: "plus.circle.fill",
                    iconColor: .green700,
                    label: "상점",
                    value: displayRewardPoints,
                    valueColor: .green700
                )

                Divider()
                    .frame(height: Constants.dividerHeight)

                pointColumn(
                    icon: "minus.circle.fill",
                    iconColor: .red700,
                    label: "벌점",
                    value: displayPenaltyPoints,
                    valueColor: .red700
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
        ScrollView(.horizontal) {
            HStack(spacing: DefaultSpacing.spacing4) {
                ForEach(uniqueGenerationPoints) { summary in
                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedGisu = summary.gisu
                        }
                    } label: {
                        Text("\(summary.gisu)기")
                            .appFont(
                                .subheadline,
                                weight: selectedGisu == summary.gisu ? .semibold : .regular,
                                color: selectedGisu == summary.gisu ? .white : .grey700
                            )
                            .padding(Constants.tagPadding)
                            .background(
                                selectedGisu == summary.gisu
                                    ? Color.accentColor : Color.grey200,
                                in: Capsule()
                            )
                            // 캡슐 자체는 그대로 두고 탭 영역만 HIG 최소 높이까지 넓힌다.
                            .frame(minHeight: Constants.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("\(summary.gisu)기 선택")
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .defaultScrollAnchor(.trailing)
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
                .appFont(.callout, weight: .semibold, color: valueColor)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            ChallengerMemberDetailSheetView(
                member: MemberManagementItem(
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
                        GenerationPointSummary(gisu: 9, reward: 0, penalty: 1),
                    ]
                )
            )
        }
}
#endif
