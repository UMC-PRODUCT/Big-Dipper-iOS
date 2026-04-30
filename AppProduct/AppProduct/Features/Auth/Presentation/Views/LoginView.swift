//
//  LoginView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import SwiftUI

/// 로그인 화면
///
/// UMC 앱의 진입점으로, 소셜 로그인 버튼을 제공합니다.
/// 중앙에 로고와 설명을 배치하고, 하단에 소셜 로그인 옵션을 표시합니다.
struct LoginView: View {

    // MARK: - Property

    /// 로그인 뷰 모델 (@Observable 패턴)
    @State private var viewModel: LoginViewModel
    @Environment(\.appFlow) private var appFlow

    // MARK: - Init

    init(
        loginUseCase: LoginUseCaseProtocol,
        loginByIdPwUseCase: LoginByIdPwUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        errorHandler: ErrorHandler
    ) {
        self._viewModel = .init(
            wrappedValue: LoginViewModel(
                loginUseCase: loginUseCase,
                loginByIdPwUseCase: loginByIdPwUseCase,
                fetchMyProfileUseCase: fetchMyProfileUseCase,
                tokenStore: tokenStore,
                errorHandler: errorHandler
            )
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: DefaultSpacing.spacing24)

            TopLogo()
                .padding(.bottom, DefaultSpacing.spacing32)

            Spacer(minLength: DefaultSpacing.spacing24)

            LoginByIdPwSection(
                loginId: $viewModel.loginIdInput,
                password: $viewModel.passwordInput,
                isLoading: viewModel.loginByIdPwState.isLoading,
                errorMessage: viewModel.loginByIdPwErrorMessage,
                onLoginTapped: {
                    Task { await viewModel.loginWithIdPw() }
                }
            )
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.bottom, DefaultSpacing.spacing24)
        }
        .safeAreaInset(edge: .bottom) {
            BottomAuthSection(
                isLoading: viewModel.loginState.isLoading,
                onSignUpTapped: {
                    appFlow.showSignUpByIdPw()
                },
                onKakaoTapped: {
                    Task { await viewModel.loginWithKakao() }
                },
                onAppleTapped: {
                    viewModel.loginWithApple()
                }
            )
            .equatable()
        }
        .onChange(of: viewModel.destination) { _, newDestination in
            guard let newDestination else { return }
            switch newDestination {
            case .main:
                appFlow.showMain()
            case .pendingApproval:
                appFlow.showPendingApproval()
            case .signUp(
                let verificationToken,
                let email,
                let fullName,
                let postRegisterLoginContext
            ):
                appFlow.showSignUp(
                    verificationToken,
                    email,
                    fullName,
                    postRegisterLoginContext
                )
            }
        }
    }
}

// MARK: - TopLogo

/// 상단 로고 영역 (Presenter 패턴)
///
/// UMC 로고 이미지와 앱 슬로건("Focus on Growth, We Handle the Ops")을 세로로 배치합니다.
/// Equatable 준수로 불필요한 렌더링을 방지합니다.
fileprivate struct TopLogo: View, Equatable {

    // MARK: - Constant

    /// 레이아웃 및 텍스트 상수
    private enum Constants {
        /// 앱 슬로건 (UMC App Statement)
        static let appStatement: String = "Focus on Growth, We Handle the Ops"
        /// 로고 이미지 너비
        static let logoImageWidth: CGFloat = 160
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            Image(.logoLight)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.logoImageWidth)
                .accessibilityHidden(true)

            Text(Constants.appStatement)
                .appFont(.subheadline, color: .grey600)
        }
    }
}

// MARK: - BottomAuthSection

/// 하단 인증 대안 그룹
///
/// "또는" 디바이더, 회원가입 진입 링크, 소셜 로그인 아이콘을 하나의 시각적 클러스터로 묶어
/// 화면 하단에 배치합니다. 폼 영역(`LoginByIdPwSection`)과 분리되어 인증 대안을 한눈에 인식할 수 있습니다.
fileprivate struct BottomAuthSection: View, Equatable {

    // MARK: - Property

    let isLoading: Bool
    var onSignUpTapped: () -> Void
    var onKakaoTapped: () -> Void
    var onAppleTapped: () -> Void

    // MARK: - Constant

    private enum Constants {
        static let dividerText: String = "또는"
        static let signUpPromptText: String = "아직 계정이 없으신가요?"
        static let signUpButtonTitle: String = "회원가입"
        static let socialButtonSize: CGFloat = 48
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isLoading == rhs.isLoading
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            dividerSection
            signUpLink
            socialButtons
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, DefaultConstant.defaultSafeBottom)
    }

    // MARK: - Subviews

    private var dividerSection: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Rectangle()
                .fill(.grey300)
                .frame(height: 1)
            Text(Constants.dividerText)
                .appFont(.footnote, color: .grey500)
            Rectangle()
                .fill(.grey300)
                .frame(height: 1)
        }
    }

    private var signUpLink: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Text(Constants.signUpPromptText)
                .appFont(.footnote, color: .grey600)
            Button(Constants.signUpButtonTitle, action: onSignUpTapped)
                .appFont(.footnoteEmphasis, color: .indigo500)
                .buttonStyle(.plain)
        }
    }

    private var socialButtons: some View {
        GlassEffectContainer {
            HStack(spacing: DefaultSpacing.spacing24) {
                ForEach(SocialType.appConnectableCases, id: \.self) { type in
                    socialButton(for: type)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func socialButton(for type: SocialType) -> some View {
        Button(action: { handleSocialTap(type) }) {
            type.image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.socialButtonSize, height: Constants.socialButtonSize)
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive().tint(type.color), in: .circle)
        .disabled(isLoading)
        .accessibilityLabel(Text(accessibilityLabel(for: type)))
        .accessibilityHint(Text("소셜 계정으로 로그인합니다"))
    }

    // MARK: - Function

    private func handleSocialTap(_ type: SocialType) {
        switch type {
        case .kakao: onKakaoTapped()
        case .apple: onAppleTapped()
        default: break
        }
    }

    private func accessibilityLabel(for type: SocialType) -> String {
        switch type {
        case .kakao: return "카카오로 로그인"
        case .apple: return "Apple로 로그인"
        default: return type.rawValue + "로 로그인"
        }
    }
}

#if DEBUG
#Preview("로그인 화면") {
    LoginView(
        loginUseCase: LoginViewPreviewLoginUseCase(),
        loginByIdPwUseCase: LoginViewPreviewLoginByIdPwUseCase(),
        fetchMyProfileUseCase: LoginViewPreviewFetchMyProfileUseCase(),
        tokenStore: KeychainTokenStore(),
        errorHandler: ErrorHandler()
    )
}

private struct LoginViewPreviewLoginUseCase: LoginUseCaseProtocol {
    func executeKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        .existingMember(
            tokenPair: TokenPair(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token"
            )
        )
    }

    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        .existingMember(
            tokenPair: TokenPair(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token"
            )
        )
    }
}

private struct LoginViewPreviewLoginByIdPwUseCase: LoginByIdPwUseCaseProtocol {
    func execute(
        loginId: String,
        password: String
    ) async throws -> LoginByIdPwResult {
        LoginByIdPwResult(
            memberId: "preview_member_id",
            tokenPair: TokenPair(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token"
            )
        )
    }
}

private struct LoginViewPreviewFetchMyProfileUseCase: FetchMyProfileUseCaseProtocol {
    func execute() async throws -> HomeProfileResult {
        HomeProfileResult(
            memberId: "1",
            schoolId: 1,
            schoolName: "UMC University",
            latestChallengerId: 1,
            latestGisuId: 1,
            chapterId: 1,
            chapterName: "Preview",
            part: .front(type: .ios),
            seasonTypes: [
                .days(1),
                .gens([1])
            ],
            roles: [],
            generations: [
                GenerationData(gisuId: 1, gen: 1, penaltyPoint: 0, rewardPoint: 0, pointLogs: [], penaltyLogs: [])
            ]
        )
    }
}
#endif
