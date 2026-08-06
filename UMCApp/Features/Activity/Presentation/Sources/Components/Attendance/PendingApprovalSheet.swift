//
//  PendingApprovalSheet.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - PendingApprovalSheet

/// 승인 대기 명단 시트
///
/// 승인 대기 참여자만 모아 개별/선택/전체 승인·반려를 처리합니다.
/// 선택 모드는 ``ToolBarCollection/OperationApprovalMenu`` 로 토글합니다.
struct PendingApprovalSheet: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var isSelecting: Bool = false
    @State private var selectedMemberIds: Set<String> = []
    @State private var alertPrompt: AlertPrompt?

    private let participants: [ParticipantAttendance]
    private let processingMemberIds: Set<String>
    private let onDecide: (ParticipantAttendance, Bool) -> Void
    private let onDecideSelected: ([ParticipantAttendance], Bool) -> Void
    private let onDecideAll: (Bool) -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - participants: 승인 대기 참여자 목록
    ///   - processingMemberIds: 결정 처리 중인 멤버 ID (중복 탭 차단)
    ///   - onDecide: 개별 결정 (승인 `true` / 반려 `false`)
    ///   - onDecideSelected: 선택 참여자 일괄 결정 — 확인 시점에 캡처한 대상만 처리한다.
    ///   - onDecideAll: 승인 대기 전원 일괄 결정 — 대상 산출을 ViewModel 에 맡겨 **확정 시점의**
    ///     승인 대기 전원을 처리한다("전체" 의 의미를 확정 순간 기준으로 해석).
    ///
    /// 세 경로 모두 **확인 Alert 를 시트 내부에서** 띄운 뒤 확정 결정을 호출한다.
    /// ViewModel 의 `alertPrompt` 는 시트 뒤 화면에 바인딩돼 있어 시트가 떠 있는 동안에는
    /// 사용자에게 보이지 않으므로, 시트에서 시작한 결정의 확인 단계는 시트가 책임진다.
    ///
    /// - Note: 반대로 결정 **실패**(예: 권한 403) 알림은 ViewModel 이 띄우므로, 시트를 닫는
    ///   선택/전체 경로에서는 즉시 보이지만 시트를 유지하는 개별 경로에서는 시트를 닫은 뒤에
    ///   표시된다(레거시와 동일). 개별 결정도 즉시 피드백하려면 결정 결과를 반환하는
    ///   ViewModel API 가 필요해 별도 티켓으로 둔다.
    init(
        participants: [ParticipantAttendance],
        processingMemberIds: Set<String>,
        onDecide: @escaping (ParticipantAttendance, Bool) -> Void,
        onDecideSelected: @escaping ([ParticipantAttendance], Bool) -> Void,
        onDecideAll: @escaping (Bool) -> Void
    ) {
        self.participants = participants
        self.processingMemberIds = processingMemberIds
        self.onDecide = onDecide
        self.onDecideSelected = onDecideSelected
        self.onDecideAll = onDecideAll
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigation(
                    naviTitle: NavigationTitle.Activity.pendingApproval,
                    displayMode: .inline
                )
                .presentationDetents([.medium, .large])
                .toolbar { toolbarContent }
                .onChange(of: isSelecting) { _, newValue in
                    if !newValue { selectedMemberIds.removeAll() }
                }
        }
        .alertPrompt(item: $alertPrompt)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if participants.isEmpty {
            ContentUnavailableView(
                "승인 대기 멤버 없음",
                systemImage: "person.crop.circle.badge.checkmark",
                description: Text("현재 승인 대기 중인 멤버가 없습니다.")
            )
        } else {
            List {
                ForEach(participants) { participant in
                    pendingRow(participant: participant)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeActions(participant: participant)
                        }
                }
            }
            .listRowSpacing(DefaultSpacing.spacing12)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolBarCollection.CancelBtn { }

        ToolBarCollection.OperationApprovalMenu(
            isSelecting: $isSelecting,
            selectedCount: selectedMemberIds.count,
            onApproveSelected: { presentSelectedDecisionAlert(isApproved: true) },
            onRejectSelected: { presentSelectedDecisionAlert(isApproved: false) },
            onApproveAll: { presentAllDecisionAlert(isApproved: true) },
            onRejectAll: { presentAllDecisionAlert(isApproved: false) }
        )
    }

    // MARK: - Row

    private func pendingRow(participant: ParticipantAttendance) -> some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            if isSelecting {
                selectionButton(participant: participant)
            }

            RemoteImage(
                urlString: participant.profileImageURL,
                size: CGSize(width: DefaultConstant.iconSize, height: DefaultConstant.iconSize),
                placeholderImage: "person.fill"
            )

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(participant.displayName)
                    .appFont(.callout, weight: .semibold, color: .grey900)
                Text(participant.schoolName)
                    .appFont(.footnote, color: .grey600)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy(duration: DefaultConstant.animationTime), value: isSelecting)
    }

    private func selectionButton(participant: ParticipantAttendance) -> some View {
        let isSelected = selectedMemberIds.contains(participant.memberId)
        return Button {
            toggleSelection(for: participant.memberId)
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: Constants.selectionIconSize))
                .foregroundStyle(isSelected ? Color.indigo500 : Color.grey400)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private func swipeActions(participant: ParticipantAttendance) -> some View {
        let isProcessing = processingMemberIds.contains(participant.memberId)

        Button {
            presentDecisionAlert(participant: participant, isApproved: true)
        } label: {
            Label("승인", systemImage: "checkmark")
        }
        .tint(Color.green500)
        .disabled(isProcessing)

        Button {
            presentDecisionAlert(participant: participant, isApproved: false)
        } label: {
            Label("거절", systemImage: "xmark")
        }
        .tint(Color.red500)
        .disabled(isProcessing)

        if let reason = participant.excuseReason, !reason.isEmpty {
            Button {
                presentExcuseAlert(participant: participant, reason: reason)
            } label: {
                Label("사유", systemImage: "text.bubble")
            }
            .tint(Color.orange500)
        }
    }

    // MARK: - Function

    private func toggleSelection(for memberId: String) {
        withAnimation(.easeInOut(duration: Constants.selectionAnimationDuration)) {
            if selectedMemberIds.contains(memberId) {
                selectedMemberIds.remove(memberId)
            } else {
                selectedMemberIds.insert(memberId)
            }
        }
    }

    /// 선택 결정 확인 — 확정 시 결정을 보내고 시트를 닫는다.
    private func presentSelectedDecisionAlert(isApproved: Bool) {
        let selected = participants.filter { selectedMemberIds.contains($0.memberId) }
        guard !selected.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: isApproved ? "선택 승인" : "선택 거절",
            message: "\(selected.count)명의 출석을 \(isApproved ? "승인" : "거절")하시겠습니까?",
            positiveBtnTitle: isApproved ? "승인" : "거절",
            positiveBtnAction: {
                onDecideSelected(selected, isApproved)
                selectedMemberIds.removeAll()
                dismiss()
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: !isApproved
        )
    }

    /// 전체 결정 확인 — 확정 시 결정을 보내고 시트를 닫는다.
    private func presentAllDecisionAlert(isApproved: Bool) {
        guard !participants.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: isApproved ? "전체 승인" : "전체 거절",
            message: "모든 승인 대기 출석을 \(isApproved ? "승인" : "거절")하시겠습니까?",
            positiveBtnTitle: isApproved ? "전체 승인" : "전체 거절",
            positiveBtnAction: {
                onDecideAll(isApproved)
                dismiss()
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: !isApproved
        )
    }

    /// 개별 결정 확인 — 문구는 이 시트의 행 라벨과 같은 ``ParticipantAttendance/displayName`` 을
    /// 쓴다(상세 화면 Alert 는 그 화면의 행 라벨인 이름을 쓴다).
    private func presentDecisionAlert(participant: ParticipantAttendance, isApproved: Bool) {
        alertPrompt = AlertPrompt(
            title: isApproved ? "출석 승인" : "출석 반려",
            message: isApproved
                ? "\(participant.displayName)님의 출석을 승인하시겠습니까?"
                : "\(participant.displayName)님의 출석을 반려하시겠습니까?",
            positiveBtnTitle: isApproved ? "승인" : "반려",
            positiveBtnAction: { onDecide(participant, isApproved) },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: !isApproved
        )
    }

    private func presentExcuseAlert(participant: ParticipantAttendance, reason: String) {
        alertPrompt = AlertPrompt(
            title: "출석 사유 확인",
            message: "\(participant.displayName)님이 작성한 사유입니다.\n\n\"\(reason)\"",
            positiveBtnTitle: "반려",
            positiveBtnAction: { onDecide(participant, false) },
            secondaryBtnTitle: "승인",
            secondaryBtnAction: { onDecide(participant, true) },
            negativeBtnTitle: "닫기",
            isPositiveBtnDestructive: true
        )
    }
}

// MARK: - Constants

private enum Constants {
    static let selectionIconSize: CGFloat = 22
    static let selectionAnimationDuration: TimeInterval = 0.2
}
