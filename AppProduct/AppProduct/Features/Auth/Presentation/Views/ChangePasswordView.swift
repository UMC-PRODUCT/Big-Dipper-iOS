//
//  ChangePasswordView.swift
//  AppProduct
//

import SwiftUI

/// 비밀번호 변경 화면
struct ChangePasswordView: View {

    // MARK: - Property

    @State private var viewModel: ChangePasswordViewModel
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var currentPasswordFocused: Bool
    @FocusState private var newPasswordFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(changePasswordUseCase: ChangePasswordUseCaseProtocol) {
        self._viewModel = .init(
            wrappedValue: ChangePasswordViewModel(
                changePasswordUseCase: changePasswordUseCase
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                UnderlineTextField(
                    label: "현재 비밀번호",
                    placeholder: "현재 비밀번호를 입력해주세요",
                    text: $viewModel.currentPasswordInput,
                    isSecure: true,
                    submitLabel: .next,
                    onSubmit: { newPasswordFocused = true },
                    focusBinding: $currentPasswordFocused
                )

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    UnderlineTextField(
                        label: "새 비밀번호",
                        placeholder: "8자 이상 입력해주세요",
                        text: $viewModel.newPasswordInput,
                        isSecure: true,
                        submitLabel: .done,
                        onSubmit: {
                            newPasswordFocused = false
                            Task { await viewModel.changePassword() }
                        },
                        focusBinding: $newPasswordFocused,
                        guideMessage: viewModel.isNewPasswordValid || viewModel.newPasswordInput.isEmpty
                            ? nil
                            : "8자 이상 입력해주세요"
                    )

                    if case .failed(let error) = viewModel.changePasswordState {
                        Text(error.userMessage)
                            .appFont(.footnote, color: .red500)
                    }
                }
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.top, DefaultConstant.defaultSafeTop)
            .padding(.bottom, DefaultConstant.defaultSafeBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Constants.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            submitButton
        }
        .alertPrompt(item: $alertPrompt)
        .onChange(of: viewModel.changePasswordState) { _, newValue in
            if case .loaded = newValue {
                alertPrompt = AlertPrompt(
                    title: "비밀번호 변경 완료",
                    message: "비밀번호가 변경되었습니다.",
                    positiveBtnTitle: "확인",
                    positiveBtnAction: { dismiss() },
                    negativeBtnTitle: nil
                )
            }
        }
    }

    // MARK: - Subviews

    private var submitButton: some View {
        MainButton(Constants.submitTitle) {
            currentPasswordFocused = false
            newPasswordFocused = false
            Task { await viewModel.changePassword() }
        }
        .loading(.constant(viewModel.changePasswordState.isLoading))
        .disabled(!viewModel.canSubmit || viewModel.changePasswordState.isLoading)
        .buttonStyle(.gradientCapsule)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, DefaultConstant.defaultSafeBottom)
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let navTitle: String = "비밀번호 변경"
    static let submitTitle: String = "변경하기"
}
