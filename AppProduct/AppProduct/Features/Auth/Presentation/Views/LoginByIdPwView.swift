//
//  LoginByIdPwView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/14/26.
//

import SwiftUI

/// ID/PW 로그인 입력 화면
///
/// `LoginView`의 NavigationStack에서 push되는 화면입니다.
/// 아이디(또는 휴대폰번호)와 비밀번호를 입력받아 로그인하며,
/// 자동로그인 체크박스와 인라인 에러 표시를 제공합니다.
struct LoginByIdPwView: View {

    // MARK: - Property

    @State private var viewModel: LoginByIdPwViewModel
    @FocusState private var loginIdFocused: Bool
    @FocusState private var passwordFocused: Bool
    @Environment(\.appFlow) private var appFlow

    // MARK: - Init

    init(
        loginByIdPwUseCase: LoginByIdPwUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        errorHandler: ErrorHandler
    ) {
        self._viewModel = .init(
            wrappedValue: LoginByIdPwViewModel(
                loginByIdPwUseCase: loginByIdPwUseCase,
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
                label: Constants.loginIdLabel,
                placeholder: Constants.loginIdPlaceholder,
                text: $viewModel.loginIdInput,
                submitLabel: .next,
                onSubmit: { passwordFocused = true },
                focusBinding: $loginIdFocused,
                guideMessage: viewModel.loginIdGuideMessage
            )
            .accessibilityLabel(Text("아이디"))
            .onChange(of: viewModel.loginIdInput) {
                viewModel.clearLoginIdGuide()
            }

            UnderlineTextField(
                label: Constants.passwordLabel,
                placeholder: Constants.passwordPlaceholder,
                text: $viewModel.passwordInput,
                isSecure: true,
                submitLabel: .done,
                onSubmit: {
                    passwordFocused = false
                    Task { await viewModel.loginWithIdPw() }
                },
                focusBinding: $passwordFocused,
                guideMessage: viewModel.passwordGuideMessage
            )
            .accessibilityLabel(Text("비밀번호"))
            .onChange(of: viewModel.passwordInput) {
                viewModel.clearPasswordGuide()
            }

            if let errorMessage = viewModel.loginByIdPwErrorMessage {
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
            signUpLink
        }
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
            loginIdFocused = false
            passwordFocused = false
            Task { await viewModel.loginWithIdPw() }
        }
        .loading(.constant(viewModel.loginByIdPwState.isLoading))
        .disabled(viewModel.loginByIdPwState.isLoading)
        .buttonStyle(.gradientCapsule)
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let navTitle: String = "로그인"
    static let loginIdLabel: String = "아이디"
    static let loginIdPlaceholder: String = "아이디를 입력하세요"
    static let passwordLabel: String = "비밀번호"
    static let passwordPlaceholder: String = "비밀번호를 입력하세요"
    static let autoLoginLabel: String = "자동로그인"
    static let loginButtonTitle: String = "로그인"
    static let signUpTitle: String = "회원가입"
    static let supportInquiryPrompt: String = "이용 중 불편사항이 있으신가요?"
    static let supportOperatingHours: String = "고객센터 운영시간 09:00 - 18:00"

    static let checkboxSize: CGFloat = 20
    static let minTouchTarget: CGFloat = 44
}

#if DEBUG
#Preview("ID/PW 로그인 화면") {
    NavigationStack {
        LoginByIdPwView(
            loginByIdPwUseCase: LoginByIdPwViewPreviewUseCase(),
            fetchMyProfileUseCase: LoginByIdPwViewPreviewProfileUseCase(),
            tokenStore: KeychainTokenStore(),
            errorHandler: ErrorHandler()
        )
    }
}

private struct LoginByIdPwViewPreviewUseCase: LoginByIdPwUseCaseProtocol {
    func execute(loginId: String, password: String) async throws -> LoginByIdPwResult {
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
