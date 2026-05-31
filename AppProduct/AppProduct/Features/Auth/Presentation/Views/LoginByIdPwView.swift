//
//  LoginByIdPwView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/14/26.
//

import SwiftUI

/// 이메일 로그인 입력 화면
///
/// `LoginView`의 NavigationStack에서 push되는 화면입니다.
/// 이메일과 비밀번호를 입력받아 로그인하며,
/// 자동로그인 체크박스와 인라인 에러 표시를 제공합니다.
struct LoginByIdPwView: View {

    // MARK: - Property

    @State private var viewModel: LoginByIdPwViewModel
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    @Environment(\.appFlow) private var appFlow

    // MARK: - Init

    init(
        loginByEmailUseCase: LoginByEmailUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        errorHandler: ErrorHandler
    ) {
        self._viewModel = .init(
            wrappedValue: LoginByIdPwViewModel(
                loginByEmailUseCase: loginByEmailUseCase,
                fetchMyProfileUseCase: fetchMyProfileUseCase,
                tokenStore: tokenStore,
                errorHandler: errorHandler
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                inputSection
                autoLoginRow
                loginButton
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.top, DefaultConstant.defaultSafeTop)
            .padding(.bottom, DefaultConstant.defaultSafeBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Constants.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.destination) { _, newDestination in
            guard let newDestination else { return }
            switch newDestination {
            case .main:
                appFlow.showMain()
            case .pendingApproval:
                appFlow.showPendingApproval()
            }
        }
    }

    // MARK: - Subviews

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
            UnderlineTextField(
                label: Constants.emailLabel,
                placeholder: Constants.emailPlaceholder,
                text: $viewModel.emailInput,
                submitLabel: .next,
                keyboardType: .emailAddress,
                onSubmit: { passwordFocused = true },
                focusBinding: $emailFocused,
                guideMessage: viewModel.emailGuideMessage
            )
            .accessibilityLabel(Text("이메일"))
            .onChange(of: viewModel.emailInput) {
                viewModel.clearEmailGuide()
            }

            UnderlineTextField(
                label: Constants.passwordLabel,
                placeholder: Constants.passwordPlaceholder,
                text: $viewModel.passwordInput,
                isSecure: true,
                submitLabel: .done,
                onSubmit: {
                    passwordFocused = false
                    Task { await viewModel.loginWithEmail() }
                },
                focusBinding: $passwordFocused,
                guideMessage: viewModel.passwordGuideMessage
            )
            .accessibilityLabel(Text("비밀번호"))
            .onChange(of: viewModel.passwordInput) {
                viewModel.clearPasswordGuide()
            }

            if let errorMessage = viewModel.loginErrorMessage {
                Text(errorMessage)
                    .appFont(.footnote, color: .red500)
                    .transition(.opacity)
            }
        }
    }

    private var autoLoginRow: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            autoLoginToggle
            Spacer()
            resetPasswordLink
            Text("|")
                .appFont(.footnote, color: .grey400)
            signUpLink
        }
    }

    private var resetPasswordLink: some View {
        NavigationLink(value: NavigationDestination.auth(.resetPassword)) {
            Text(Constants.resetPasswordTitle)
                .appFont(.footnote, color: .grey500)
        }
        .buttonStyle(.plain)
        .frame(minHeight: Constants.minTouchTarget)
        .accessibilityHint(Text("비밀번호 찾기 화면으로 이동합니다"))
    }

    private var autoLoginToggle: some View {
        Button {
            viewModel.isAutoLoginEnabled.toggle()
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(
                    systemName: viewModel.isAutoLoginEnabled
                    ? "checkmark.square.fill"
                    : "square"
                )
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.checkboxSize, height: Constants.checkboxSize)
                .foregroundStyle(viewModel.isAutoLoginEnabled ? .indigo500 : .grey400)
                Text(Constants.autoLoginLabel)
                    .appFont(.subheadline, color: .grey600)
            }
            .frame(minHeight: Constants.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("자동로그인"))
        .accessibilityValue(
            Text(viewModel.isAutoLoginEnabled ? "선택됨" : "선택 안됨")
        )
        .accessibilityAddTraits(.isButton)
    }

    private var signUpLink: some View {
        NavigationLink(value: NavigationDestination.auth(.signUpByIdPw)) {
            Text(Constants.signUpTitle)
                .appFont(.footnote, color: .grey500)
        }
        .buttonStyle(.plain)
        .frame(minHeight: Constants.minTouchTarget)
        .accessibilityHint(Text("회원가입 화면으로 이동합니다"))
    }

    private var loginButton: some View {
        MainButton(Constants.loginButtonTitle) {
            emailFocused = false
            passwordFocused = false
            Task { await viewModel.loginWithEmail() }
        }
        .loading(.constant(viewModel.loginByEmailState.isLoading))
        .disabled(!viewModel.canSubmit)
        .buttonStyle(.glassProminent)
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let navTitle: String = "로그인"
    static let emailLabel: String = "이메일"
    static let emailPlaceholder: String = "이메일을 입력하세요"
    static let passwordLabel: String = "비밀번호"
    static let passwordPlaceholder: String = "비밀번호를 입력하세요"
    static let autoLoginLabel: String = "자동로그인"
    static let loginButtonTitle: String = "로그인"
    static let signUpTitle: String = "회원가입"
    static let resetPasswordTitle: String = "비밀번호 찾기"

    static let checkboxSize: CGFloat = 20
    static let minTouchTarget: CGFloat = 44
}

#if DEBUG
#Preview("이메일 로그인 화면") {
    NavigationStack {
        LoginByIdPwView(
            loginByEmailUseCase: LoginByIdPwViewPreviewUseCase(),
            fetchMyProfileUseCase: LoginByIdPwViewPreviewProfileUseCase(),
            tokenStore: KeychainTokenStore(),
            errorHandler: ErrorHandler()
        )
    }
}

private struct LoginByIdPwViewPreviewUseCase: LoginByEmailUseCaseProtocol {
    func execute(email: String, password: String) async throws -> LoginByIdPwResult {
        LoginByIdPwResult(
            memberId: "preview_member_id",
            tokenPair: TokenPair(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token"
            )
        )
    }
}

private struct LoginByIdPwViewPreviewProfileUseCase: FetchMyProfileUseCaseProtocol {
    func execute() async throws -> HomeProfileResult {
        HomeProfileResult(
            memberId: "1",
            schoolId: 1,
            schoolName: "UMC University",
            latestChallengerId: nil,
            latestGisuId: nil,
            chapterId: nil,
            chapterName: "",
            part: nil,
            seasonTypes: [.days(0), .gens([])],
            roles: [],
            generations: []
        )
    }
}
#endif
