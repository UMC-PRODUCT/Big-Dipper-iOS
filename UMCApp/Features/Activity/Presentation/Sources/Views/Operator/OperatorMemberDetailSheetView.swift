//
//  OperatorMemberDetailSheetView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - OperatorMemberDetailSheetView

/// 운영진 멤버 상세 정보 및 상벌점 관리 시트 뷰
///
/// 상태·액션은 `OperatorMemberDetailSheetViewModel`이 담당합니다.
/// 상벌점 부여 폼은 `PointGrantFormSheet`으로 분리되어 있으며, ViewModel을 공유합니다.
struct OperatorMemberDetailSheetView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    let member: MemberManagementItem
    let availablePointTypes: [ChallengerPointType]
    let isSubmittingPoint: Bool
    let isDeletingPoint: Bool

    @State private var viewModel: OperatorMemberDetailSheetViewModel

    // MARK: - Constants

    private enum Constants {
        static let contentHorizontalPadding: CGFloat = 16
        static let contentSpacing: CGFloat = 24
        static let baseHeight: CGFloat = 340
        static let maxVisibleHistory: Int = 7
        static let minVisibleHistoryHeight: CGFloat = 180
        static let minSheetHeight: CGFloat = 420
        static let maxSheetHeight: CGFloat = 820
    }

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
        _viewModel = State(
            initialValue: OperatorMemberDetailSheetViewModel(
                onGrantPoint: onGrantPoint,
                onDeletePoint: onDeletePoint
            )
        )
    }

    // MARK: - Computed Property

    private var dynamicSheetHeight: CGFloat {
        let height = Constants.baseHeight
            + historyAreaHeight(for: viewModel.penaltyHistory.count)
        return max(Constants.minSheetHeight, min(height, Constants.maxSheetHeight))
    }

    /// 하단 안내 문구. 일시적 에러 메시지가 있을 경우 우선 표시.
    private var historyDescription: String {
        if let message = viewModel.transientHistoryMessage { return message }
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
            .animation(
                OperatorMemberDetailSheetViewModel.animation,
                value: viewModel.penaltyHistory.count
            )
            .sheet(isPresented: $viewModel.showPointForm) {
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
        ToolBarCollection.AddBtn(
            imageSystemName: "plus.circle.fill",
            action: { viewModel.showPointForm = true },
            isLoading: isSubmittingPoint
        )
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
                .appFont(
                    .footnote,
                    color: viewModel.transientHistoryMessage == nil ? .grey500 : .red
                )

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
    }

    // MARK: - Function

    /// 히스토리 표시 영역 높이. 0건이면 최소 높이, 1건 이상이면 행 높이 합산에 최소 높이를 하한으로 건다.
    ///
    /// 행 높이는 실제로 행을 그리는 ``PenaltyHistoryRowPresenter`` 의 상수를 그대로 읽는다.
    /// 값을 따로 들고 있으면 행 높이만 바뀌었을 때 시트 높이 계산이 조용히 어긋난다.
    private func historyAreaHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return Constants.minVisibleHistoryHeight }
        let visible = min(count, Constants.maxVisibleHistory)
        let rowsHeight = CGFloat(visible) * PenaltyHistoryRowPresenter.Constants.rowHeight
            + CGFloat(visible - 1) * DefaultSpacing.spacing8
        return max(rowsHeight, Constants.minVisibleHistoryHeight)
    }
}

// MARK: - MemberInfoSectionPresenter

/// 멤버 프로필 이미지, 이름/닉네임, 파트·학교·운영진 칩을 표시하는 섹션
private struct MemberInfoSectionPresenter: View, Equatable {

    // MARK: - Property

    let member: MemberManagementItem

    // MARK: - Constants

    private enum Constants {
        static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
        static let profileSize: CGSize = .init(width: 60, height: 60)
        static let partTagOpacity: Double = 0.14
        static let partStrokeOpacity: Double = 0.4
        static let partStrokeWidth: CGFloat = 1
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(urlString: member.profile ?? "", size: Constants.profileSize)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                Text("\(member.nickname)/\(member.name)")
                    .appFont(.body, weight: .semibold)

                HStack(spacing: DefaultSpacing.spacing8) {
                    accentChip(title: member.part.name, tint: member.part.color)
                    schoolChip(title: member.school)

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
            .overlay {
                Capsule()
                    .stroke(
                        tint.opacity(Constants.partStrokeOpacity),
                        lineWidth: Constants.partStrokeWidth
                    )
            }
    }

    private func schoolChip(title: String) -> some View {
        Text(title)
            .appFont(.callout, color: .grey700)
            .padding(Constants.tagPadding)
            .background(.regularMaterial, in: Capsule())
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

    // MARK: - Constants

    private enum Constants {
        static let badgePadding: EdgeInsets = .init(top: 6, leading: 8, bottom: 6, trailing: 8)
        static let bgOpacity: Double = 0.2
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Label(
                "히스토리",
                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
            )
            .appFont(.title3, weight: .semibold)

            if totalReward > 0 {
                pointBadge(label: "상점 \(formatted(totalReward))", color: .green)
            }

            if totalPenalty > 0 {
                pointBadge(label: "벌점 \(formatted(totalPenalty))", color: .red)
            }
        }
    }

    // MARK: - Function

    private func formatted(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private func pointBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.app(.footnote, weight: .regular))
            .foregroundStyle(color)
            .padding(Constants.badgePadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                    .fill(color.opacity(Constants.bgOpacity))
            }
    }
}

// MARK: - PenaltyHistoryRowPresenter

/// 상벌점 히스토리 개별 행: 날짜 · 사유 · 점수
private struct PenaltyHistoryRowPresenter: View, Equatable {

    // MARK: - Property

    let history: OperatorMemberPenaltyHistory

    // MARK: - Constants

    /// `rowHeight` 는 시트 높이 계산(``OperatorMemberDetailSheetView/historyAreaHeight(for:)``)도
    /// 함께 읽으므로 `fileprivate` 로 연다.
    fileprivate enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let rowHeight: CGFloat = 50
    }

    // MARK: - Body

    var body: some View {
        let isReward = history.pointType.isReward

        HStack(spacing: DefaultSpacing.spacing16) {
            Text(history.date.toYearMonthDay())
                .appFont(.subheadline, weight: .semibold)

            Text(history.reason)
                .appFont(.subheadline)
                .lineLimit(1)

            Spacer()

            Text("\(isReward ? "+" : "-")\(String(format: "%.0f", history.penaltyScore))")
                .appFont(.subheadline, color: isReward ? .green : .red)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: Constants.rowHeight)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
        )
    }
}

// MARK: - EmptyHistoryPresenter

/// 히스토리가 없거나 열람 불가일 때 표시되는 빈 상태 뷰
private struct EmptyHistoryPresenter: View, Equatable {

    // MARK: - Property

    /// `true`이면 "기록 없음", `false`이면 "열람 불가" 메시지를 표시
    let canViewHistory: Bool

    // MARK: - Constants

    private enum Constants {
        static let height: CGFloat = 150
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "exclamationmark.bubble.fill")
                .appFont(.title1, color: .grey500)

            Text(canViewHistory ? "포인트 기록이 없습니다" : "타인의 포인트 히스토리를 확인할 수 없습니다")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.height)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
        )
    }
}

// MARK: - Preview

#if DEBUG
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
            ),
        ]
    )
}

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
#endif
