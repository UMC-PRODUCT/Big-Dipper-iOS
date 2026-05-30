//
//  ResetPasswordView.swift
//  AppProduct
//

import SwiftUI

/// 비밀번호 찾기 화면
///
/// 흐름: 이메일 입력/인증 → 새 비밀번호 입력 → 변경 완료 시 로그인 화면으로 복귀.
struct ResetPasswordView: View {

    // MARK: - Property

    @State private var viewModel: ResetPasswordViewModel
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var newPasswordFocused: Bool
    @FocusState private var newPasswordConfirmFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(
        sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
        resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol,
        verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
        resetPasswordUseCase: ResetPasswordUseCaseProtocol
    ) {
        self._viewModel = .init(
            wrappedValue: ResetPasswordViewModel(
                sendEmailVerificationUseCase: sendEmailVerificationUseCase,
                resendEmailVerificationUseCase: resendEmailVerificationUseCase,
                verifyEmailCodeUseCase: verifyEmailCodeUseCase,
                resetPasswordUseCase: resetPasswordUseCase
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                FormEmailField(
                    title: "이메일",
                    placeholder: "example@example.com",
                    text: $viewModel.emailInput,
                    onVerificationRequested: {
                        try await viewModel.requestEmailVerification()
                    },
                    onVerificationComplete: { code in
                        try await viewModel.verifyEmailCode(code)
                    },
                    onResend: {
                        try await viewModel.resendEmailVerification()
                    },
                    submitLabel: .next,
                    onSubmit: { newPasswordFocused = true },
                    onEmailChanged: { viewModel.resetEmailVerification() }
                )

                Text(Constants.deliveryNotice)
                    .appFont(.footnote, color: .grey500)

                if viewModel.isEmailVerified {
                    passwordSection
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
        .onChange(of: viewModel.resetState) { _, newValue in
            if case .loaded = newValue {
                alertPrompt = AlertPrompt(
                    title: "비밀번호 변경 완료",
                    message: "변경된 비밀번호로 로그인해주세요.",
                    positiveBtnTitle: "확인",
                    positiveBtnAction: { dismiss() },
                    negativeBtnTitle: nil
                )
            }
        }
    }

    // MARK: - Subviews

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            UnderlineTextField(
                label: "새 비밀번호",
                placeholder: "8자 이상 입력해주세요",
                text: $viewModel.newPasswordInput,
                isSecure: true,
                submitLabel: .next,
                onSubmit: { newPasswordConfirmFocused = true },
                focusBinding: $newPasswordFocused,
                guideMessage: viewModel.isPasswordValid || viewModel.newPasswordInput.isEmpty
                    ? nil
                    : "8자 이상 입력해주세요"
            )

            UnderlineTextField(
                label: "새 비밀번호 확인",
                placeholder: "한 번 더 입력해주세요",
                text: $viewModel.newPasswordConfirmInput,
                isSecure: true,
                submitLabel: .done,
                onSubmit: {
                    newPasswordConfirmFocused = false
                    Task { await viewModel.resetPassword() }
                },
                focusBinding: $newPasswordConfirmFocused,
                guideMessage: viewModel.isPasswordConfirmed || viewModel.newPasswordConfirmInput.isEmpty
                    ? nil
                    : "비밀번호가 일치하지 않습니다"
            )

            if case .failed(let error) = viewModel.resetState {
                Text(error.userMessage)
                    .appFont(.footnote, color: .red500)
            }
        }
    }

    private var submitButton: some View {
        MainButton(Constants.submitTitle) {
            newPasswordFocused = false
            newPasswordConfirmFocused = false
            Task { await viewModel.resetPassword() }
        }
        .loading(.constant(viewModel.resetState.isLoading))
        .disabled(!viewModel.canSubmit || viewModel.resetState.isLoading)
        .buttonStyle(.gradientCapsule)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, DefaultConstant.defaultSafeBottom)
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let navTitle: String = "비밀번호 찾기"
    static let deliveryNotice: String = "메일이 도착하지 않으면 가입 여부를 확인해주세요."
    static let submitTitle: String = "비밀번호 변경"
}
