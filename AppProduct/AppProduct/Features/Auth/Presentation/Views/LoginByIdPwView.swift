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
                autoLoginToggle
                loginButton
                Spacer(minLength: DefaultSpacing.spacing24)
                bottomActions
                supportFooter
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.top, DefaultConstant.defaultSafeTop)
            .padding(.bottom, DefaultConstant.defaultSafeBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Constants.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                homeButton
            }
        }
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
                focusBinding: $loginIdFocused
            )
            .accessibilityLabel(Text("아이디 또는 휴대폰번호"))

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
                focusBinding: $passwordFocused
            )
            .accessibilityLabel(Text("비밀번호"))

            if let errorMessage = viewModel.loginByIdPwErrorMessage {
                Text(errorMessage)
                    .appFont(.footnote, color: .red500)
                    .transition(.opacity)
            }
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
                Spacer()
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

    private var loginButton: some View {
        MainButton(Constants.loginButtonTitle) {
            loginIdFocused = false
            passwordFocused = false
            Task { await viewModel.loginWithIdPw() }
        }
        .loading(.constant(viewModel.loginByIdPwState.isLoading))
        .disabled(
            viewModel.loginIdInput.isEmpty
            || viewModel.passwordInput.isEmpty
            || viewModel.loginByIdPwState.isLoading
        )
        .buttonStyle(.gradientCapsule)
    }

    private var bottomActions: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            HStack(spacing: DefaultSpacing.spacing4) {
                Button(Constants.findIdTitle) {
                    #if DEBUG
                    print("[Auth] 아이디 찾기 — 미구현 (준비 중)")
                    #endif
                }
                .appFont(.caption1, color: .grey600)
                .buttonStyle(.plain)

                Text("/")
                    .appFont(.caption1, color: .grey400)

                Button(Constants.resetPasswordTitle) {
                    #if DEBUG
                    print("[Auth] 비밀번호 재설정 — 미구현 (준비 중)")
                    #endif
                }
                .appFont(.caption1, color: .grey600)
                .buttonStyle(.plain)
            }
            .frame(minHeight: Constants.minTouchTarget)

            Spacer()

            Button(Constants.signUpTitle) {
                appFlow.showSignUpByIdPw()
            }
            .appFont(.caption1Emphasis, color: .indigo500)
            .buttonStyle(.plain)
            .frame(minHeight: Constants.minTouchTarget)
            .accessibilityHint(Text("회원가입 화면으로 이동합니다"))
        }
    }

    private var supportFooter: some View {
        VStack(spacing: DefaultSpacing.spacing4) {
            Text(Constants.supportText1)
                .appFont(.caption1, color: .grey500)
            Text(Constants.supportText2)
                .appFont(.caption1, color: .grey500)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var homeButton: some View {
        Button {
            appFlow.showMain()
        } label: {
            Image(systemName: "house")
                .foregroundStyle(.grey700)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let navTitle: String = "로그인"
    static let loginIdLabel: String = "아이디 또는 휴대폰번호"
    static let loginIdPlaceholder: String = "아이디 또는 휴대폰번호를 입력하세요"
    static let passwordLabel: String = "비밀번호"
    static let passwordPlaceholder: String = "비밀번호를 입력하세요"
    static let autoLoginLabel: String = "자동로그인"
    static let loginButtonTitle: String = "로그인"
    static let findIdTitle: String = "아이디 찾기"
    static let resetPasswordTitle: String = "비밀번호 재설정"
    static let signUpTitle: String = "회원가입"
    static let supportText1: String = "이용 중 불편사항이 있으신가요?"
    static let supportText2: String = "고객센터 운영시간 09:00 - 18:00"

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
