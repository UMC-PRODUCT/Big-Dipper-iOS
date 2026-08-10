//
//  ChangePasswordView.swift
//  AuthPresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDesignSystem
import CoreDI
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 비밀번호 변경 화면 — 로그인한 회원이 현재 비밀번호를 확인받고 새 비밀번호로 교체한다.
///
/// - Note: 마이페이지에서 push되는 화면이므로 자체 `NavigationStack`을 두지 않는다
///   (`ResetPasswordView`와 동일).
public struct ChangePasswordView: View {

    // MARK: - Property

    @State private var viewModel: ChangePasswordViewModel
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var focusedField: ChangePasswordFocusField?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constant

    fileprivate enum Constants {
        static let currentPasswordTitle: String = "현재 비밀번호"
        static let currentPasswordPlaceholder: String = "현재 비밀번호를 입력해 주세요"
        static let newPasswordTitle: String = "새 비밀번호"
        static let newPasswordPlaceholder: String = "8자 이상 입력"
        static let newPasswordGuide: String = "8자 이상 입력해 주세요."
        static let submitTitle: String = "변경하기"
        static let completedTitle: String = "비밀번호 변경 완료"
        static let completedMessage: String = "변경된 비밀번호로 다시 로그인해 주세요."
        static let confirmTitle: String = "확인"
        static let messageLeadingPadding: CGFloat = 10
    }

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        _viewModel = State(initialValue: ChangePasswordViewModel(
            container: container,
            errorHandler: errorHandler
        ))
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                currentPasswordField
                newPasswordField
                changeErrorMessageView
            }
            .safeAreaPadding(.vertical, DefaultConstant.defaultContentTopMargins)
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigation(naviTitle: NavigationTitle.Auth.changePassword, displayMode: .inline)
        .safeAreaInset(edge: .bottom) {
            submitButton
        }
        .onChange(of: viewModel.changePasswordState) { _, newState in
            handleChangePasswordStateChange(newState)
        }
        .alertPrompt(item: $alertPrompt)
    }

    // MARK: - Subviews

    private var currentPasswordField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.currentPasswordTitle, isRequired: true)

            SecureField(
                "",
                text: $viewModel.currentPassword,
                prompt: Text(Constants.currentPasswordPlaceholder).font(.app(.callout))
            )
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.next)
            .focused($focusedField, equals: .currentPassword)
            .onSubmit { focusedField = .newPassword }
            .accessibilityLabel(Text(Constants.currentPasswordTitle))
        }
    }

    private var newPasswordField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.newPasswordTitle, isRequired: true)

            SecureField(
                "",
                text: $viewModel.newPassword,
                prompt: Text(Constants.newPasswordPlaceholder).font(.app(.callout))
            )
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .focused($focusedField, equals: .newPassword)
            .onSubmit { submit() }
            .accessibilityLabel(Text(Constants.newPasswordTitle))

            if !viewModel.newPassword.isEmpty, !viewModel.isNewPasswordValid {
                guideMessage(Constants.newPasswordGuide)
            }
        }
    }

    @ViewBuilder
    private var changeErrorMessageView: some View {
        if let changePasswordErrorMessage = viewModel.changePasswordErrorMessage {
            guideMessage(changePasswordErrorMessage)
        }
    }

    private func guideMessage(_ message: String) -> some View {
        Text(message)
            .appFont(.footnote, color: .red500)
            .padding(.leading, Constants.messageLeadingPadding)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if viewModel.changePasswordState.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(Constants.submitTitle)
                        .appFont(.subheadline, weight: .semibold, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultConstant.defaultBtnPadding)
        }
        .buttonStyle(.glassProminent)
        .tint(.indigo500)
        .disabled(!viewModel.canSubmit || viewModel.changePasswordState.isLoading)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Function

    private func submit() {
        focusedField = nil
        Task { await viewModel.changePassword() }
    }

    private func handleChangePasswordStateChange(_ newState: Loadable<Bool>) {
        guard case .loaded = newState else { return }

        alertPrompt = AlertPrompt(
            title: Constants.completedTitle,
            message: Constants.completedMessage,
            positiveBtnTitle: Constants.confirmTitle,
            positiveBtnAction: { dismiss() }
        )
    }
}

// MARK: - Focus Field

/// 비밀번호 변경 화면의 키보드 포커스 대상 필드.
fileprivate enum ChangePasswordFocusField: Hashable {
    case currentPassword
    case newPassword
}
