//
//  MessageReportSheet.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

fileprivate enum Constants {
    static let navigationTitle = "신고"
    static let submitTitle = "신고하기"
    static let dismissTitle = "취소"
    /// 신고를 누르기 직전에 가장 궁금한 두 가지 — 누가 보는지, 내 이름이 남는지.
    static let privacyNotice = "신고 내용은 스레드 개설자만 확인하며, 신고자는 익명으로 처리돼요."
    static let reasonSectionTitle = "신고 사유"
    static let noticeImage = "lock.shield"
    static let failureImage = "exclamationmark.triangle"
    /// 최소 터치 타깃 (접근성 명세 SECTION 07).
    static let rowMinHeight: CGFloat = 44
    static let noticeIconSize: CGFloat = 16
}

/// 신고 사유 택1 시트.
///
/// 사유는 서버 `ReportReason` 5종 고정이고 자유 서술 칸은 없다 — "기타" 를 골라도 함께 보낼
/// 필드가 서버에 없어서, 입력란을 두면 쓴 내용이 조용히 버려진다.
struct MessageReportSheet: View {

    // MARK: - Property

    let viewModel: CommunityThreadRoomViewModel

    /// 고른 사유. 시트를 닫으면 함께 사라지는 값이라 ViewModel 로 올리지 않는다.
    @State private var selection: ThreadMessageReportReason?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section { privacyNotice }

                Section(Constants.reasonSectionTitle) {
                    ForEach(ThreadMessageReportReason.allCases, id: \.self) { reason in
                        reasonRow(reason)
                    }
                }

                if let error = viewModel.reportState.error {
                    Section { failureLabel(error) }
                }
            }
            .navigationTitle(Constants.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Constants.dismissTitle) { dismiss() }
                        .appFont(.body, color: .grey700)
                }
            }
            .safeAreaInset(edge: .bottom) { submitButton }
        }
        .presentationDetents([.medium, .large])
        // 시트를 밀어 내리든 취소를 누르든 남은 실패 문구는 여기서 정리된다.
        .onDisappear { viewModel.dismissReport() }
    }

    // MARK: - View Component

    private var privacyNotice: some View {
        HStack(alignment: .firstTextBaseline, spacing: DefaultSpacing.spacing8) {
            Image(systemName: Constants.noticeImage)
                .font(.system(size: Constants.noticeIconSize))
                .foregroundStyle(Color.indigo500)

            Text(Constants.privacyNotice)
                .appFont(.footnote, color: .grey600)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func reasonRow(_ reason: ThreadMessageReportReason) -> some View {
        let isSelected = reason == selection

        return Button {
            selection = reason
        } label: {
            HStack {
                Text(reason.displayName)
                    .appFont(.body, weight: isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.indigo500 : Color.grey900)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.indigo500)
                }
            }
            .frame(minHeight: Constants.rowMinHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func failureLabel(_ error: AppError) -> some View {
        Label(error.userMessage, systemImage: Constants.failureImage)
            .appFont(.footnote, color: Color.red500)
    }

    /// 사유를 고르기 전에는 보낼 것이 없어 잠가 둔다 (완료 조건 2).
    private var submitButton: some View {
        MainButton(Constants.submitTitle) {
            guard let selection else { return }
            Task { await viewModel.submitReport(reason: selection) }
        }
        .buttonSize(.large)
        .buttonStyle(.glassProminent)
        .disabled(selection == nil || viewModel.reportState.isLoading)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.vertical, DefaultSpacing.spacing12)
        .background(.bar)
    }
}
