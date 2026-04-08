//
//  OperatorStudyGroupEditSheet.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/11/26.
//

import SwiftUI

/// 스터디 그룹 정보 수정 시트
///
/// 그룹 이름과 소속 파트를 수정할 수 있는 시트입니다.
struct OperatorStudyGroupEditSheet: View {
    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: OperatorStudyManagementViewModel
    @State private var isSaving = false

    fileprivate enum Constants {
        static let allParts: [UMCPartType] = UMCPartType.allCases
        static let sectionSpacing: CGFloat = 20
        static let blockSpacing: CGFloat = 8
        static let fieldHeight: CGFloat = 50
        static let fieldHorizontalPadding: CGFloat = 16
        static let contentHorizontalPadding: CGFloat = 20
        static let contentTopPadding: CGFloat = 20
        static let fieldCornerRadius: CGFloat = 16
    }

    // MARK: - Initializer

    /// - Parameter viewModel: 스터디 관리 ViewModel (`editingName`, `editingPart`로 상태를 관리합니다)
    init(viewModel: OperatorStudyManagementViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                    nameSection
                    partSection
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
        .presentationDetents([.fraction(0.4)])
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
                .foregroundStyle(.black)
                .autocorrectionDisabled(true)
                .padding(.horizontal, Constants.fieldHorizontalPadding)
                .frame(height: Constants.fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: Constants.fieldCornerRadius)
                        .fill(Color.grey100)
                )

            Text("예시) React A팀")
                .appFont(.footnote, color: .grey500)
        }
    }

    private var partSection: some View {
        VStack(alignment: .leading, spacing: Constants.blockSpacing) {
            Text("소속 파트")
                .appFont(.subheadline, color: .grey700)

            Menu {
                ForEach(Constants.allParts, id: \.self) { part in
                    Button {
                        viewModel.editingPart = part
                    } label: {
                        HStack {
                            Image(systemName: part.icon)
                            Text(part.name)
                            if viewModel.editingPart == part {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(part.color)
                }
            } label: {
                HStack(spacing: Constants.blockSpacing) {
                    Image(systemName: viewModel.editingPart.icon)
                        .foregroundStyle(viewModel.editingPart.color)
                    Text(viewModel.editingPart.name)
                        .appFont(.body, color: viewModel.editingPart.color)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.grey500)
                }
                .padding(.horizontal, Constants.fieldHorizontalPadding)
                .frame(height: Constants.fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: Constants.fieldCornerRadius)
                        .fill(Color.grey100)
                )
            }
        }
    }

    // MARK: - Action

    private var isSaveDisabled: Bool {
        viewModel.editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard !isSaveDisabled else { return }
        guard !isSaving else { return }
        isSaving = true

        Task { @MainActor in
            guard let groupID = viewModel.editingGroup?.id else {
                isSaving = false
                return
            }
            let isSuccess = await viewModel.updateGroup(
                groupID: groupID,
                name: viewModel.editingName.trimmingCharacters(in: .whitespacesAndNewlines),
                part: viewModel.editingPart
            )
            isSaving = false
            if isSuccess {
                dismiss()
            }
        }
    }
}
