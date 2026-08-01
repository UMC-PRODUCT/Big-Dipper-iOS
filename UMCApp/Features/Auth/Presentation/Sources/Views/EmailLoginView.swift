//
//  EmailLoginView.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/31/26.
//

import CoreDesignSystem
import CoreDI
import CoreDomain
import SwiftUI
import UMCFoundation

/// 이메일(ID/PW) 로그인 입력 화면.
///
/// `LoginView`의 `NavigationStack`에서 push되며, 이메일·비밀번호를 입력받아 로그인한다.
/// 인증 실패는 인라인 메시지로 표시하고, 승인 여부에 따라 메인 또는 승인 대기 화면으로
/// 전환한다. "비밀번호 찾기"·"회원가입"도 이 화면에서 push로 진입한다.
public struct EmailLoginView: View {

    // MARK: - Property

    @State private var viewModel: EmailLoginViewModel
    @FocusState private var focusedField: LoginFocusField?
    @Environment(\.appFlow) private var appFlow

    /// 비밀번호 재설정·회원가입 화면을 push할 때 그대로 전달하기 위해 보관한다.
    private let container: DIContainer
    private let errorHandler: ErrorHandler

    // MARK: - Constant

    fileprivate enum Constants {
        static let navigationTitle: String = "로그인"
        static let emailTitle: String = "이메일"
        static let emailPlaceholder: String = "example@example.com"
        static let passwordTitle: String = "비밀번호"
        static let passwordPlaceholder: String = "비밀번호를 입력해 주세요"
        static let resetPasswordTitle: String = "비밀번호 찾기"
        static let signUpTitle: String = "회원가입"
        static let submitTitle: String = "로그인"
        static let messageLeadingPadding: CGFloat = 10
        static let minimumTouchTarget: CGFloat = 44
    }

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
        _viewModel = State(initialValue: EmailLoginViewModel(
            container: container,
            errorHandler: errorHandler
        ))
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                emailField
                passwordField
                loginErrorMessageView
                authLinksRow
                submitButton
            }
            .safeAreaPadding(.vertical, DefaultConstant.defaultContentTopMargins)
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Constants.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.loginState) { _, newState in
            handle(newState: newState)
        }
    }

    // MARK: - Subviews

    private var emailField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.emailTitle, isRequired: true)

            TextField(
                "",
                text: $viewModel.emailInput,
                prompt: Text(Constants.emailPlaceholder).font(.app(.callout))
            )
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.next)
            .focused($focusedField, equals: .email)
            .onSubmit { focusedField = .password }
            .onChange(of: viewModel.emailInput) { _, _ in
                viewModel.clearEmailGuide()
            }
            .accessibilityLabel(Text(Constants.emailTitle))

            if let emailGuideMessage = viewModel.emailGuideMessage {
                guideMessage(emailGuideMessage)
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.passwordTitle, isRequired: true)

            SecureField(
                "",
                text: $viewModel.passwordInput,
                prompt: Text(Constants.passwordPlaceholder).font(.app(.callout))
            )
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .focused($focusedField, equals: .password)
            .onSubmit { submit() }
            .onChange(of: viewModel.passwordInput) { _, _ in
                viewModel.clearPasswordGuide()
            }
            .accessibilityLabel(Text(Constants.passwordTitle))

            if let passwordGuideMessage = viewModel.passwordGuideMessage {
                guideMessage(passwordGuideMessage)
            }
        }
    }

    @ViewBuilder
    private var loginErrorMessageView: some View {
        if let loginErrorMessage = viewModel.loginErrorMessage {
            Text(loginErrorMessage)
                .appFont(.footnote, color: .red500)
                .padding(.leading, Constants.messageLeadingPadding)
                .transition(.opacity)
        }
    }

    /// "회원가입"·"비밀번호 찾기"를 한 행에 나란히 배치한다(왼쪽 정렬 회원가입, 오른쪽
    /// 정렬 비밀번호 찾기) — 두 진입점 모두 보조 링크 성격이 같아 한 행에 묶는 편이
    /// 자연스럽다고 판단했다.
    private var authLinksRow: some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            signUpLink
            resetPasswordLink
        }
    }

    private var signUpLink: some View {
        NavigationLink {
            SignUpByIdPwView(container: container, errorHandler: errorHandler)
        } label: {
            Text(Constants.signUpTitle)
                .appFont(.footnote, color: .grey500)
                .frame(minHeight: Constants.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("회원가입 화면으로 이동합니다"))
    }

    private var resetPasswordLink: some View {
        NavigationLink {
            ResetPasswordView(container: container, errorHandler: errorHandler)
        } label: {
            Text(Constants.resetPasswordTitle)
                .appFont(.footnote, color: .grey500)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(minHeight: Constants.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("비밀번호 재설정 화면으로 이동합니다"))
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if viewModel.loginState.isLoading {
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
        .disabled(!viewModel.canSubmit || viewModel.loginState.isLoading)
    }

    private func guideMessage(_ message: String) -> some View {
        Text(message)
            .appFont(.footnote, color: .red500)
            .padding(.leading, Constants.messageLeadingPadding)
    }

    // MARK: - Function

    private func submit() {
        focusedField = nil
        Task { await viewModel.loginWithEmail() }
    }

    /// 로그인 상태 전이를 앱 전역 흐름으로 연결한다 (`LoginView.handle(newState:)`와 동일 규약).
    private func handle(newState: Loadable<Profile>) {
        if case .loaded = newState {
            appFlow.showMain()
        }
        if newState == .failed(.auth(.pendingApproval)) {
            appFlow.showPendingApproval()
        }
    }
}
