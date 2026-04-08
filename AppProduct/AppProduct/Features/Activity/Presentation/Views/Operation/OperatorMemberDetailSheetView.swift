//
//  OperatorMemberDetailSheetView.swift
//  AppProduct
//
//  Created by 이예지 on 2/16/26.
//

import SwiftUI

// MARK: - OperatorMemberDetailSheetView

/// 운영진 멤버 상세 정보 및 상벌점 관리 시트 뷰
///
/// 상태·액션은 `OperatorMemberDetailSheetViewModel`이 담당합니다.
/// 상벌점 부여 폼은 `PointGrantFormSheet`으로 분리되어 있으며, ViewModel을 공유합니다.
struct OperatorMemberDetailSheetView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    var member: MemberManagementItem
    let availablePointTypes: [ChallengerPointType]
    let isSubmittingPoint: Bool
    let isDeletingPoint: Bool

    @State private var viewModel: OperatorMemberDetailSheetViewModel

    // MARK: - Init

    init(
        member: MemberManagementItem,
        availablePointTypes: [ChallengerPointType],
        isSubmittingPoint: Bool,
        isDeletingPoint: Bool,
        onGrantPoint: @escaping @Sendable (ChallengerPointType, Int, String) async -> Bool,
        onDeletePoint: @escaping @Sendable (OperatorMemberPenaltyHistory) async -> String?
    ) {
        self.member = member
        self.availablePointTypes = availablePointTypes
        self.isSubmittingPoint = isSubmittingPoint
        self.isDeletingPoint = isDeletingPoint
        _viewModel = State(initialValue: OperatorMemberDetailSheetViewModel(
            onGrantPoint: onGrantPoint,
            onDeletePoint: onDeletePoint
        ))
    }

    // MARK: - Constants

    private enum Constants {
        static let contentHorizontalPadding: CGFloat = 16
        static let contentSpacing: CGFloat = 24
        static let baseHeight: CGFloat = 340
        static let emptyHistoryHeight: CGFloat = 150
        static let historyRowHeight: CGFloat = 50
        static let maxVisibleHistory: Int = 7
        static let minVisibleHistoryHeight: CGFloat = 180
        static let minSheetHeight: CGFloat = 420
        static let maxSheetHeight: CGFloat = 820
    }

    // MARK: - Computed Property

    /// 히스토리 표시 영역 높이. 0건일 때는 빈 상태 뷰 높이, 이상일 때는 행 높이 합산.
    private func historyAreaHeight(for count: Int) -> CGFloat {
        guard count > 0 else {
            return max(Constants.emptyHistoryHeight, Constants.minVisibleHistoryHeight)
        }
        let visible = min(count, Constants.maxVisibleHistory)
        let rowsHeight = CGFloat(visible) * Constants.historyRowHeight
            + CGFloat(visible - 1) * DefaultSpacing.spacing8
        return max(rowsHeight, Constants.minVisibleHistoryHeight)
    }

    private var dynamicSheetHeight: CGFloat {
        let h = Constants.baseHeight + historyAreaHeight(for: viewModel.penaltyHistory.count)
        return max(Constants.minSheetHeight, min(h, Constants.maxSheetHeight))
    }

    private var scrollViewHeight: CGFloat {
        historyAreaHeight(for: viewModel.penaltyHistory.count)
    }

    /// 하단 안내 문구. 일시적 에러 메시지가 있을 경우 우선 표시.
    private var historyDescription: String {
        if let msg = viewModel.transientHistoryMessage { return msg }
        return member.canViewPenaltyHistory
            ? "히스토리 항목을 왼쪽으로 밀어서 삭제할 수 있습니다."
            : "본인이 아닌 경우 포인트 히스토리를 확인할 수 없습니다."
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                MemberInfoSectionPresenter(member: member)
                historySection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .toolbar { toolbarItems }
            .padding(.horizontal, Constants.contentHorizontalPadding)
            .scrollContentBackground(.hidden)
            .presentationDetents([.height(dynamicSheetHeight)])
            .interactiveDismissDisabled()
            .animation(OperatorMemberDetailSheetViewModel.animation, value: viewModel.penaltyHistory.count)
            .fullScreenCover(isPresented: $viewModel.showPointForm) {
                PointGrantFormSheet(
                    availablePointTypes: availablePointTypes,
                    isSubmittingPoint: isSubmittingPoint,
                    viewModel: viewModel
                )
            }
        }
        .onChange(of: member) { _, newValue in viewModel.syncState(from: newValue) }
        .task { viewModel.syncState(from: member) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolBarCollection.CancelBtn { dismiss() }
        ToolbarItem(placement: .topBarTrailing) {
            Button { viewModel.showPointForm = true } label: {
                if isSubmittingPoint {
                    ProgressView().tint(.blue)
                } else {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
                }
            }
            .tint(.blue)
            .disabled(isSubmittingPoint)
        }
    }

    // MARK: - SubView

    /// 히스토리 헤더·안내문·목록을 묶은 섹션
    private var historySection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HistoryHeaderPresenter(
                totalReward: viewModel.totalReward,
                totalPenalty: viewModel.totalPenalty
            )
            Text(historyDescription)
                .appFont(.footnote, color: viewModel.transientHistoryMessage == nil ? .grey500 : .red)

            if viewModel.penaltyHistory.isEmpty {
                EmptyHistoryPresenter(canViewHistory: member.canViewPenaltyHistory)
            } else {
                historyListView
            }
        }
    }

    /// 히스토리 목록 (스와이프 삭제 지원)
    private var historyListView: some View {
        List {
            ForEach(viewModel.penaltyHistory) { history in
                PenaltyHistoryRowPresenter(history: history)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deletePenalty(
                                    history,
                                    canView: member.canViewPenaltyHistory
                                )
                            }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    .disabled(isDeletingPoint || !member.canViewPenaltyHistory)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init())
            }
        }
        .listStyle(.plain)
        .listRowSpacing(DefaultSpacing.spacing8)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
//        .frame(height: scrollViewHeight)
    }
}

// MARK: - MemberInfoSectionPresenter

/// 멤버 프로필 이미지, 이름/닉네임, 파트·학교·운영진 칩을 표시하는 섹션
private struct MemberInfoSectionPresenter: View, Equatable {

    // MARK: - Property

    let member: MemberManagementItem

    private enum Constants {
        static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
        static let profileSize: CGSize = .init(width: 60, height: 60)
        static let partTagOpacity: Double = 0.14
        static let partStrokeOpacity: Double = 0.4
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(urlString: member.profile ?? "", size: Constants.profileSize)
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                Text("\(member.nickname)/\(member.name)").appFont(.bodyEmphasis)
                HStack(spacing: DefaultSpacing.spacing8) {
                    accentChip(title: member.part.name, tint: member.part.color)
                    plainChip(title: member.school)
                    if member.managementTeam != .challenger {
                        ManagementTeamBadgePresenter(managementTeam: member.managementTeam)
                    }
                }
            }
        }
    }

    // MARK: - Function

    private func accentChip(title: String, tint: Color) -> some View {
        Text(title)
            .appFont(.callout, color: tint)
            .padding(Constants.tagPadding)
            .background(tint.opacity(Constants.partTagOpacity), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(Constants.partStrokeOpacity), lineWidth: 1) }
    }

    private func plainChip(title: String) -> some View {
        Text(title).appFont(.callout, color: .black)
            .padding(Constants.tagPadding)
            .background(.white, in: Capsule())
    }
}

// MARK: - HistoryHeaderPresenter

/// 히스토리 섹션 헤더: 제목 레이블 + 상점/벌점 배지
///
/// 합계가 0인 경우 해당 배지를 표시하지 않습니다.
private struct HistoryHeaderPresenter: View, Equatable {

    // MARK: - Property

    let totalReward: Double
    let totalPenalty: Double

    private enum Constants {
        static let badgePadding: EdgeInsets = .init(top: 6, leading: 8, bottom: 6, trailing: 8)
        static let bgOpacity: Double = 0.2
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Label("히스토리", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .appFont(.title3Emphasis)
            if totalReward > 0 { pointBadge(label: "상점 \(String(format: "%.0f", totalReward))", color: .green) }
            if totalPenalty > 0 { pointBadge(label: "벌점 \(String(format: "%.0f", totalPenalty))", color: .red) }
        }
    }

    // MARK: - Function

    private func pointBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.app(.footnote, weight: .regular))
            .foregroundStyle(color)
            .padding(Constants.badgePadding)
            .background(RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                .fill(color.opacity(Constants.bgOpacity)))
    }
}

// MARK: - PenaltyHistoryRowPresenter

/// 상벌점 히스토리 개별 행: 날짜 · 사유 · 점수
private struct PenaltyHistoryRowPresenter: View, Equatable {

    // MARK: - Property

    let history: OperatorMemberPenaltyHistory

    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let rowHeight: CGFloat = 50
    }

    // MARK: - Body

    var body: some View {
        let isReward = history.pointType.isReward

        HStack(spacing: DefaultSpacing.spacing16) {
            Text(history.date.toYearMonthDay()).appFont(.subheadlineEmphasis)
            Text(history.reason).appFont(.subheadline).lineLimit(1)
            Spacer()
            Text("\(isReward ? "+" : "-")\(String(format: "%.0f", history.penaltyScore))")
                .appFont(.subheadline, color: isReward ? .green : .red)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: Constants.rowHeight)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
    }
}

// MARK: - EmptyHistoryPresenter

/// 히스토리가 없거나 열람 불가일 때 표시되는 빈 상태 뷰
private struct EmptyHistoryPresenter: View, Equatable {

    // MARK: - Property

    /// `true`이면 "기록 없음", `false`이면 "열람 불가" 메시지를 표시
    let canViewHistory: Bool

    private enum Constants { static let height: CGFloat = 150 }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "exclamationmark.bubble.fill").appFont(.title1, color: .grey500)
            Text(canViewHistory ? "포인트 기록이 없습니다" : "타인의 포인트 히스토리를 확인할 수 없습니다")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.height)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }
}

// MARK: - Preview

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            OperatorMemberDetailSheetView(
                member: OperatorMemberDetailSheetView.previewMember,
                availablePointTypes: ChallengerPointType.availableTypes(for: 30),
                isSubmittingPoint: false,
                isDeletingPoint: false,
                onGrantPoint: { _, _, _ in true },
                onDeletePoint: { _ in nil }
            )
        }
}

private extension OperatorMemberDetailSheetView {
    static let previewMember = MemberManagementItem(
        profile: nil,
        name: "김미주",
        nickname: "마티",
        generation: "9기",
        school: "덕성여자대학교",
        position: "Challenger",
        part: .front(type: .ios),
        penalty: 4,
        rewardPoints: 3,
        badge: false,
        managementTeam: .schoolPartLeader,
        attendanceRecords: [],
        penaltyHistory: [
            OperatorMemberPenaltyHistory(
                date: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                reason: "스터디 지각",
                penaltyScore: 2.0,
                pointType: .studyLate
            ),
            OperatorMemberPenaltyHistory(
                date: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                reason: "우수 워크북",
                penaltyScore: 2.0,
                pointType: .bestWorkbook
            ),
            OperatorMemberPenaltyHistory(
                date: Date().addingTimeInterval(-3 * 24 * 60 * 60),
                reason: "스터디 결석",
                penaltyScore: 4.0,
                pointType: .studyAbsent
            )
        ]
    )
}
