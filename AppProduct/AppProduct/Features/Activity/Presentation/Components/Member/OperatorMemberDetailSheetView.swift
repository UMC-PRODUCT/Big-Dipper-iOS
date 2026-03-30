//
//  OperatorMemberDetailSheetView.swift
//  AppProduct
//
//  Created by 이예지 on 2/16/26.
//

import SwiftUI

/// 운영진 멤버 상세 정보 및 상벌점 관리 시트 뷰
struct OperatorMemberDetailSheetView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    var member: MemberManagementItem
    let availablePointTypes: [ChallengerPointType]
    let isSubmittingPoint: Bool
    let isDeletingPoint: Bool
    let onGrantPoint: @Sendable (ChallengerPointType, Int, String) async -> Bool
    let onDeletePoint: @Sendable (OperatorMemberPenaltyHistory) async -> String?
    @State private var showPointForm: Bool = false
    @State private var selectedPointType: ChallengerPointType?
    @State private var pointValue: Int = 0
    @State private var customPointValueText: String = ""
    @State private var pointReason: String = ""
    @State private var penaltyHistory: [OperatorMemberPenaltyHistory] = []
    @State private var totalPenalty: Double = 0
    @State private var totalReward: Double = 0
    @State private var showReasonAlert: Bool = false
    @State private var transientHistoryMessage: String?
    @State private var transientHistoryMessageTask: Task<Void, Never>?

    // MARK: - Constant

    private enum Constants {
        static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
        static let profileSize: CGSize = .init(width: 60, height: 60)
        static let contentHorizontalPadding: CGFloat = 16
        static let contentTopPadding: CGFloat = 8
        static let contentBottomPadding: CGFloat = 0
        static let contentSpacing: CGFloat = 24

        static let baseHeight: CGFloat = 340
        static let emptyHistoryHeight: CGFloat = 150
        static let historyRowHeight: CGFloat = 50
        static let maxVisibleHistory: Int = 7
        static let minimumVisibleHistoryHeight: CGFloat = 180
        static let minSheetHeight: CGFloat = 420
        static let maxSheetHeight: CGFloat = 820
        static let badgePadding: EdgeInsets = .init(top: 6, leading: 8, bottom: 6, trailing: 8)
        static let bgOpacity: Double = 0.2
        static let animation: Animation = .spring(response: 0.34, dampingFraction: 0.86)
    }

    // MARK: - Computed Properties

    private var isReasonValid: Bool {
        !pointReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var partTint: Color {
        member.part.color
    }

    private var dynamicSheetHeight: CGFloat {
        let historyCount = penaltyHistory.count

        var calculatedHeight: CGFloat = Constants.baseHeight

        if historyCount == 0 {
            calculatedHeight += max(
                Constants.emptyHistoryHeight,
                Constants.minimumVisibleHistoryHeight
            )
        } else {
            let visibleHistory = min(historyCount, Constants.maxVisibleHistory)
            let historyHeight = (CGFloat(visibleHistory) * Constants.historyRowHeight)
                + (CGFloat(max(0, visibleHistory - 1)) * DefaultSpacing.spacing8)
            calculatedHeight += max(
                historyHeight,
                Constants.minimumVisibleHistoryHeight
            )
        }

        return max(Constants.minSheetHeight, min(calculatedHeight, Constants.maxSheetHeight))
    }

    private var scrollViewHeight: CGFloat {
        let recordCount = penaltyHistory.count

        if recordCount == 0 {
            return max(
                Constants.emptyHistoryHeight,
                Constants.minimumVisibleHistoryHeight
            )
        }

        let visibleHistory = min(recordCount, Constants.maxVisibleHistory)
        let historyHeight = (CGFloat(visibleHistory) * Constants.historyRowHeight)
            + (CGFloat(max(0, visibleHistory - 1)) * DefaultSpacing.spacing8)

        return max(
            historyHeight,
            Constants.minimumVisibleHistoryHeight
        )
    }

    private var rewardTypes: [ChallengerPointType] {
        availablePointTypes.filter { $0.isReward }
    }

    private var penaltyTypes: [ChallengerPointType] {
        availablePointTypes.filter { !$0.isReward }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                memberInfoView
                historyView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .toolbar { toolbarItems }
            .padding(.horizontal, Constants.contentHorizontalPadding)
            .padding(.bottom, Constants.contentBottomPadding)
            .scrollContentBackground(.hidden)
            .presentationDetents([.height(dynamicSheetHeight)])
            .interactiveDismissDisabled()
            .animation(Constants.animation, value: penaltyHistory.count)
            .fullScreenCover(isPresented: $showPointForm) {
                pointFormSheet
            }
        }
        .onChange(of: member) { _, newValue in
            penaltyHistory = newValue.penaltyHistory
            totalPenalty = newValue.penalty
            totalReward = newValue.rewardPoints
        }
        .task {
            penaltyHistory = member.penaltyHistory
            totalPenalty = member.penalty
            totalReward = member.rewardPoints
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolBarCollection.CancelBtn {
            dismiss()
        }
        ToolbarItem(placement: .topBarTrailing) {
            pointTriggerButton
        }
    }

    private var pointTriggerButton: some View {
        Button {
            selectedPointType = nil
            pointValue = 0
            customPointValueText = ""
            pointReason = ""
            showPointForm = true
        } label: {
            if isSubmittingPoint {
                ProgressView()
                    .tint(.blue)
            } else {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .tint(.blue)
        .disabled(isSubmittingPoint)
    }

    // MARK: - Point Form Sheet

    /// CUSTOM 타입의 배점 유효성
    private var isCustomPointValueValid: Bool {
        guard selectedPointType?.isCustom == true else { return true }
        guard let value = Int(customPointValueText), value != 0 else { return false }
        return true
    }

    /// 확정 버튼 활성 조건
    private var isConfirmEnabled: Bool {
        selectedPointType != nil && isCustomPointValueValid && !isSubmittingPoint
    }

    private var pointFormSheet: some View {
        NavigationStack {
            Form {
                if !rewardTypes.isEmpty {
                    Section {
                        ForEach(rewardTypes) { type in
                            pointTypeRow(type: type, tint: .green)
                        }
                    } header: {
                        Text("상점")
                    }
                }

                Section {
                    ForEach(penaltyTypes) { type in
                        pointTypeRow(type: type, tint: .red)
                    }
                } header: {
                    Text("벌점")
                }

                if let selected = selectedPointType, selected.isCustom {
                    Section("배점") {
                        HStack {
                            Text("점수 입력")
                                .appFont(.subheadline)
                            Spacer()
                            TextField("예: 3 또는 -2", text: $customPointValueText)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .onChange(of: customPointValueText) { _, newValue in
                                    if let parsed = Int(newValue) {
                                        pointValue = parsed
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("상벌점 부여")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolBarCollection.CancelBtn { }
                ToolBarCollection.ConfirmBtn(
                    action: {
                        pointReason = ""
                        showReasonAlert = true
                    },
                    disable: !isConfirmEnabled,
                    isLoading: isSubmittingPoint,
                    dismissOnTap: false
                )
            }
            .alert("사유 입력", isPresented: $showReasonAlert) {
                TextField("사유를 입력하세요", text: $pointReason)
                Button("취소", role: .cancel) {
                    pointReason = ""
                }
                Button("확인") {
                    Task {
                        await addPoint()
                    }
                }
                .disabled(!isReasonValid)
            } message: {
                if let selected = selectedPointType {
                    Text("\(selected.displayName) (\(pointValue > 0 ? "+" : "")\(pointValue)점) 사유를 입력해주세요.")
                }
            }
        }
    }

    private func pointTypeRow(
        type: ChallengerPointType,
        tint: Color
    ) -> some View {
        let isSelected = selectedPointType == type

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPointType = type
                if type.isCustom {
                    customPointValueText = ""
                    pointValue = 0
                } else {
                    pointValue = type.defaultPointValue
                }
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tint : .grey400)
                    .contentTransition(.symbolEffect(.replace))

                Text(type.displayName)
                    .appFont(.subheadline, color: .primary)

                Spacer()

                if !type.isCustom {
                    Text("\(type.defaultPointValue > 0 ? "+" : "")\(type.defaultPointValue)")
                        .appFont(.subheadlineEmphasis, color: isSelected ? tint : .grey500)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - SubView

    private var memberInfoView: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(urlString: member.profile ?? "", size: Constants.profileSize)
            memberMetadataView
        }
    }

    private var memberMetadataView: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Text("\(member.nickname)/\(member.name)")
                .appFont(.bodyEmphasis)
            HStack(spacing: DefaultSpacing.spacing8) {
                statusChip(title: member.part.name, style: .accent)
                statusChip(title: member.school, style: .plain)
                if member.managementTeam != .challenger {
                    ManagementTeamBadgePresenter(managementTeam: member.managementTeam)
                }
            }
        }
    }

    private enum StatusChipStyle {
        case accent
        case plain
    }

    @ViewBuilder
    private func statusChip(title: String, style: StatusChipStyle) -> some View {
        switch style {
        case .accent:
            Text(title)
                .appFont(.callout, color: partTint)
                .padding(Constants.tagPadding)
                .background(partTint.opacity(0.14), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(partTint.opacity(0.4), lineWidth: 1)
                }
        case .plain:
            Text(title)
                .appFont(.callout, color: .black)
                .padding(Constants.tagPadding)
                .background(.white, in: Capsule())
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            historyHeader
            historyDescription
            historyListContainer
        }
    }

    private var historyHeader: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Label("히스토리", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .appFont(.title3Emphasis)

            if totalReward > 0 {
                pointBadge(label: "상점 \(String(format: "%.0f", totalReward))", color: .green)
            }
            if totalPenalty > 0 {
                pointBadge(label: "벌점 \(String(format: "%.0f", totalPenalty))", color: .red)
            }
        }
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

    private var historyListContainer: some View {
        Group {
            if penaltyHistory.isEmpty {
                emptyHistoryView
            } else {
                historyListView
            }
        }
    }

    private var historyDescription: some View {
        Text(resolvedHistoryDescription)
            .appFont(
                .footnote,
                color: transientHistoryMessage == nil ? .grey500 : .red
            )
    }

    private var emptyHistoryView: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "exclamationmark.bubble.fill")
                .appFont(.title1, color: .grey500)
            Text(member.canViewPenaltyHistory ? "포인트 기록이 없습니다" : "타인의 포인트 히스토리를 확인할 수 없습니다")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.emptyHistoryHeight)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }

    private var historyListView: some View {
        List {
            ForEach(penaltyHistory) { history in
                penaltyHistoryRow(history)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await deletePenalty(history)
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

    private func penaltyHistoryRow(_ history: OperatorMemberPenaltyHistory) -> some View {
        let isReward = history.pointType.isReward
        let color: Color = isReward ? .green : .red
        let sign = isReward ? "+" : "-"

        return HStack(spacing: DefaultSpacing.spacing16) {
            Text(history.date.toYearMonthDay())
                .appFont(.subheadlineEmphasis)

            Text(history.reason)
                .appFont(.subheadline)
                .lineLimit(1)

            Spacer()

            Text("\(sign)\(String(format: "%.0f", history.penaltyScore))")
                .appFont(.subheadline, color: color)
        }
        .padding(.horizontal, Constants.contentHorizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: Constants.historyRowHeight)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
    }

    // MARK: - Function

    @MainActor
    private func addPoint() async {
        guard member.canViewPenaltyHistory else { return }
        guard let selectedType = selectedPointType else { return }
        guard !pointReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let reason = pointReason
        let value = pointValue
        let isSuccess = await onGrantPoint(selectedType, value, reason)
        guard isSuccess else { return }

        let newHistory = OperatorMemberPenaltyHistory(
            date: Date(),
            reason: reason,
            penaltyScore: Double(abs(value)),
            pointType: selectedType
        )

        withAnimation(Constants.animation) {
            penaltyHistory.append(newHistory)
            penaltyHistory.sort { $0.date > $1.date }
        }

        let isRewardPoint = selectedType.isCustom ? value > 0 : selectedType.isReward
        if isRewardPoint {
            totalReward += Double(abs(value))
        } else {
            totalPenalty += Double(abs(value))
        }

        showPointForm = false
        pointReason = ""
        customPointValueText = ""
        selectedPointType = nil
    }

    @MainActor
    private func deletePenalty(_ history: OperatorMemberPenaltyHistory) async {
        guard member.canViewPenaltyHistory else { return }
        if let message = await onDeletePoint(history) {
            showTransientHistoryMessage(message)
            return
        }

        if let index = penaltyHistory.firstIndex(where: { $0.id == history.id }) {
            let deletedScore = penaltyHistory[index].penaltyScore
            let isReward = penaltyHistory[index].pointType.isReward
            withAnimation(Constants.animation) {
                penaltyHistory.remove(at: index)
                if isReward {
                    totalReward -= deletedScore
                } else {
                    totalPenalty -= deletedScore
                }
            }
        }
    }

    private var resolvedHistoryDescription: String {
        if let transientHistoryMessage,
           !transientHistoryMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return transientHistoryMessage
        }

        if member.canViewPenaltyHistory {
            return "히스토리 항목을 왼쪽으로 밀어서 삭제할 수 있습니다."
        }
        return "본인이 아닌 경우 포인트 히스토리를 확인할 수 없습니다."
    }

    private func showTransientHistoryMessage(_ message: String) {
        transientHistoryMessageTask?.cancel()
        transientHistoryMessage = message
        transientHistoryMessageTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                transientHistoryMessage = nil
                transientHistoryMessageTask = nil
            }
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true), content: {
            OperatorMemberDetailSheetView(
                member: OperatorMemberDetailSheetView.previewMember,
                availablePointTypes: ChallengerPointType.availableTypes(for: 30),
                isSubmittingPoint: false,
                isDeletingPoint: false,
                onGrantPoint: { _, _, _ in true },
                onDeletePoint: { _ in nil }
            )
        })
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
