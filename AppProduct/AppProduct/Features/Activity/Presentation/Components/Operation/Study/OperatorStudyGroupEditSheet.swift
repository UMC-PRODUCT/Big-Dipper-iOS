//
//  OperatorStudyGroupEditSheet.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/11/26.
//

import SwiftUI

/// 스터디 그룹 정보 수정 시트
///
/// 그룹 이름을 수정할 수 있는 시트입니다.
struct OperatorStudyGroupEditSheet: View {
    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: OperatorStudyManagementViewModel
    @State private var isSaving = false

    fileprivate enum Constants {
        static let sectionSpacing: CGFloat = 20
        static let blockSpacing: CGFloat = 8
        static let fieldHeight: CGFloat = 50
        static let fieldHorizontalPadding: CGFloat = 16
        static let contentHorizontalPadding: CGFloat = 20
        static let contentTopPadding: CGFloat = 20
    }

    // MARK: - Initializer

    /// - Parameter viewModel: 스터디 관리 ViewModel (`editingName`으로 상태를 관리합니다)
    init(viewModel: OperatorStudyManagementViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                    nameSection
                }
                .padding(.horizontal, Constants.contentHorizontalPadding)
                .padding(.top, Constants.contentTopPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("그룹 정보 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolBarCollection.CancelBtn {}
                ToolBarCollection.ConfirmBtn(
                    action: submit,
                    disable: isSaveDisabled || isSaving,
                    isLoading: isSaving,
                    dismissOnTap: false
                )
            }
        }
        .presentationDetents([.fraction(0.3)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Constants.blockSpacing) {
            Text("그룹 이름")
                .appFont(.subheadline, color: .grey700)

            TextField("그룹 이름 지정", text: $viewModel.editingName)
                .multilineTextAlignment(.leading)
                .autocorrectionDisabled(true)
                .padding(.horizontal, Constants.fieldHorizontalPadding)
                .frame(height: Constants.fieldHeight)
                .background(
                    ConcentricRectangle(
                        corners: .concentric(minimum: DefaultConstant.concentricRadius)
                    )
                    .fill(Color.grey100)
                )

            Text("예시) React A팀")
                .appFont(.footnote, color: .grey500)
        }
    }

    // MARK: - Action

    private var isSaveDisabled: Bool {
        viewModel.editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard !isSaving else { return }
        isSaving = true

        Task { @MainActor in
            guard let groupID = viewModel.editingGroup?.id else {
                isSaving = false
                return
            }
            let isSuccess = await viewModel.updateGroup(
                groupID: groupID,
                name: viewModel.editingName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isSaving = false
            if isSuccess {
                dismiss()
            }
        }
    }
}
