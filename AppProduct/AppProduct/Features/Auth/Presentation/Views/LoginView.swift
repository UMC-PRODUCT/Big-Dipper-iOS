//
//  LoginView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import SwiftUI

/// 소셜 로그인 진입 화면
///
/// 앱의 최초 인증 진입점으로, 소셜 로그인 버튼(카카오/Apple)과
/// "아이디 또는 휴대폰번호 로그인" 진입 버튼을 제공합니다.
/// 내부 `NavigationStack`으로 `LoginByIdPwView`를 push합니다.
struct LoginView: View {

    // MARK: - Property

    @State private var viewModel: LoginViewModel
    @State private var navPath: [NavigationDestination] = []
    @Environment(\.appFlow) private var appFlow
    @Environment(ErrorHandler.self) private var errorHandler

    /// 카카오톡 UMC 문의 채널 연동 매니저
    private let kakaoPlusManager: KakaoPlusManager = .init()

    // MARK: - Init

    init(
        loginUseCase: LoginUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        errorHandler: ErrorHandler
    ) {
        self._viewModel = .init(
            wrappedValue: LoginViewModel(
                loginUseCase: loginUseCase,
                fetchMyProfileUseCase: fetchMyProfileUseCase,
                tokenStore: tokenStore,
                errorHandler: errorHandler
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navPath) {
            content
                .navigationDestination(for: NavigationDestination.self) { destination in
                    NavigationRoutingView(destination: destination)
                }
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

    // MARK: - Subviews

    private var content: some View {
        VStack(spacing: .zero) {
            Spacer()

            LogoSection()
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

            Spacer()

            actionSection
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .padding(.bottom, DefaultConstant.defaultSafeBottom)
        }
    }

    private var actionSection: some View {
        VStack(spacing: DefaultSpacing.spacing32) {
            loginSection(content: {
                kakaoLoginButton
                appleLoginButton
            })
            
            Divider()
            
            loginSection(content: {
                idPwLoginButton
                supportFooter
            })
        }
    }
    
    private func loginSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            content()
        }
    }
    
    private var kakaoLoginButton: some View {
        Button {
            Task { await viewModel.loginWithKakao() }
        } label: {
            SocialLoginLabel(.kakao)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.loginState.isLoading)
        .accessibilityLabel(Text("카카오로 시작하기"))
        .accessibilityHint(Text("카카오 계정으로 로그인합니다"))
    }

    private var appleLoginButton: some View {
        Button {
            viewModel.loginWithApple()
        } label: {
            SocialLoginLabel(.apple)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.loginState.isLoading)
        .accessibilityLabel(Text("Apple로 시작하기"))
        .accessibilityHint(Text("Apple 계정으로 로그인합니다"))
    }

    private var idPwLoginButton: some View {
        NavigationLink(value: NavigationDestination.auth(.loginByIdPw)) {
            SocialLoginLabel(.email)
        }
        .buttonBorderShape(.capsule)
        .disabled(viewModel.loginState.isLoading)
        .accessibilityHint(Text("아이디와 비밀번호 입력 화면으로 이동합니다"))
        .overlay {
            Capsule()
                .fill(.clear)
                .strokeBorder(Color.grey500, style: .init(lineWidth: 0.5))
        }
    }

    private var supportFooter: some View {
        VStack(spacing: DefaultSpacing.spacing4) {
            Text(Constants.supportInquiryPrompt)
                .appFont(.footnote, color: .grey500)
            HStack(spacing: .zero) {
                Button {
                    kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
                } label: {
                    Text(Constants.supportChannelLabel)
                        .foregroundStyle(.indigo)
                        .appFont(.footnote, color: .grey500)
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("고객센터로 문의하기"))
                .accessibilityHint(Text("카카오톡 UMC 문의 채널을 엽니다"))

                Text(Constants.supportChannelSuffix)
                    .appFont(.footnote, color: .grey500)
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - LogoSection

/// 로고 + 슬로건 영역
fileprivate struct LogoSection: View, Equatable {

    private enum Constants {
        static let appStatement: String = "Focus on Growth, We Handle the Ops"
        static let appSubtitle: String = "동아리 활동을 한 곳에서"
        static let logoImageWidth: CGFloat = 160
    }

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Image(.logoLight)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.logoImageWidth)
                .accessibilityHidden(true)

            VStack(spacing: DefaultSpacing.spacing4) {
                Text(Constants.appSubtitle)
                    .appFont(.callout, color: .grey700)
                Text(Constants.appStatement)
                    .appFont(.subheadline, color: .grey500)
            }
        }
    }
}

// MARK: - SocialLoginLabel

/// 소셜 로그인 버튼 라벨 (브랜드 컬러 캡슐)
///
/// 좌측 로고(20pt) + 중앙 정렬 텍스트로 구성된 풀-위드 캡슐 버튼 라벨.
/// 디자인 시스템 토큰만 사용하며, 브랜드 색은 호출부에서 토큰으로 주입합니다.
fileprivate struct SocialLoginLabel: View {

    let loginType: SocialType
    
    init(_ loginType: SocialType) {
        self.loginType = loginType
    }

    private enum LayoutConstants {
        static let leadingPadding: CGFloat = 16
        static let btnHeight: CGFloat = 48
    }

    var body: some View {
        ZStack(alignment: .leading, content: {
            Text(loginType.rawValue)
                .appFont(.callout, color: loginType.fontColor)
                .frame(maxWidth: .infinity)
                .frame(height: LayoutConstants.btnHeight)
                .background(loginType.color, in: .capsule)
            
            loginLogo
        })
    }

    @ViewBuilder
    private var loginLogo: some View {
        loginType.image
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: loginType.iconSize, height: loginType.iconSize)
            .accessibilityHidden(true)
            .padding(.leading, LayoutConstants.leadingPadding)
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let idPwLoginTitle: String = "아이디 또는 휴대폰번호 로그인"
    static let naverButtonTitle: String = "네이버로 시작하기"
    static let kakaoButtonTitle: String = "카카오로 시작하기"
    static let appleButtonTitle: String = "Apple로 시작하기"
    static let supportInquiryPrompt: String = "로그인에 문제가 있으신가요?"
    static let supportChannelLabel: String = "고객센터"
    static let supportChannelSuffix: String = "로 문의해 주세요."
    static let socialButtonHeight: CGFloat = 52
}

#if DEBUG
#Preview("소셜 로그인 진입 화면") {
    LoginView(
        loginUseCase: LoginViewPreviewLoginUseCase(),
        fetchMyProfileUseCase: LoginViewPreviewFetchMyProfileUseCase(),
        tokenStore: KeychainTokenStore(),
        errorHandler: ErrorHandler()
    )
    .environment(ErrorHandler())
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
                GenerationData(
                    gisuId: 1,
                    gen: 1,
                    penaltyPoint: 0,
                    rewardPoint: 0,
                    pointLogs: [],
                    penaltyLogs: []
                )
            ]
        )
    }
}
#endif
