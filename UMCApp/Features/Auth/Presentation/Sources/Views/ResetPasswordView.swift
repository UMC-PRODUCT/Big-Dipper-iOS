import AuthDomain
import CoreDesignSystem
import CoreDI
import SwiftUI
import UMCFoundation

/// 비밀번호 재설정 화면 — 이메일 인증(`PASSWORD_RESET` 목적) 후 새 비밀번호를 입력받아
/// 재설정을 완료한다.
///
/// - Note: 프로덕션 네비게이션 배선은 이 Task(#947)의 범위가 아니다. 실제 진입 경로는
///   ID/PW 로그인 화면(#943)이 이식된 뒤 그 화면에서 연결되며, 이 화면은 `#if DEBUG`
///   진입점(`AppRootView`)을 통해서만 현재 리뷰/QA 가능하다.
public struct ResetPasswordView: View {

    // MARK: - Property

    @State private var viewModel: ResetPasswordViewModel
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var focusedField: SignUpFocusField?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constant

    fileprivate enum Constants {
        static let deliveryNotice: String = "메일이 도착하지 않으면 가입 여부를 확인해주세요."
        static let submitTitle: String = "비밀번호 변경"
        static let completedTitle: String = "비밀번호 변경 완료"
        static let completedMessage: String = "변경된 비밀번호로 로그인해주세요."
        static let confirmTitle: String = "확인"
    }

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        _viewModel = State(initialValue: ResetPasswordViewModel(
            container: container,
            errorHandler: errorHandler
        ))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                    FormEmailField(
                        title: "이메일",
                        placeholder: "example@example.com",
                        text: $viewModel.email,
                        isVerified: $viewModel.isEmailVerified,
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
                        onSubmit: { focusedField = .password },
                        onEmailChanged: { viewModel.handleEmailChanged() }
                    )

                    Text(Constants.deliveryNotice)
                        .appFont(.footnote, color: .grey500)

                    if viewModel.isEmailVerified {
                        SignUpPasswordSection(
                            password: $viewModel.newPassword,
                            passwordConfirm: $viewModel.newPasswordConfirm,
                            isPasswordValid: viewModel.isPasswordValid,
                            isPasswordConfirmed: viewModel.isPasswordConfirmed,
                            focusBinding: $focusedField,
                            onConfirmSubmit: { focusedField = nil }
                        )
                    }
                }
                .safeAreaPadding(.vertical, DefaultConstant.defaultContentTopMargins)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigation(naviTitle: .resetPassword, displayMode: .inline)
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
        }
        .onChange(of: viewModel.resetPasswordState) { _, newState in
            handleResetPasswordStateChange(newState)
        }
        .alertPrompt(item: $alertPrompt)
    }

    // MARK: - Subviews

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.resetPassword() }
        } label: {
            Group {
                if viewModel.resetPasswordState.isLoading {
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
        .disabled(!viewModel.canSubmit || viewModel.resetPasswordState.isLoading)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Function

    private func handleResetPasswordStateChange(_ newState: Loadable<Bool>) {
        guard case .loaded = newState else { return }

        alertPrompt = AlertPrompt(
            title: Constants.completedTitle,
            message: Constants.completedMessage,
            positiveBtnTitle: Constants.confirmTitle,
            positiveBtnAction: { dismiss() }
        )
    }
}
