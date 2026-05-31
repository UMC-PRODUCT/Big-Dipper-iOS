//
//  LoginView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//
//  소셜 로그인 진입 화면 (logout 후 fallback).
//
//  앱 최초 진입은 `AuthBootstrapView` 가 처리하며, 시네마틱 종료 후 같은 화면 안에서
//  `LoginActionStack` 을 morph 시킨다. LoginView 는 logout 후 다시 로그인 단계로 돌아왔을 때
//  시네마틱 없이 즉시 보여주는 fallback 진입점이다 — 시각·layout 은 AuthBootstrapView 의
//  `.loginReady` stage 와 동일하게 유지한다.
//

import SwiftUI

/// 소셜 로그인 진입 화면 (logout 후 fallback).
///
/// 로고 + 슬로건(상단) + LoginActionStack(하단) 의 정적 layout. AuthBootstrapView 의
/// `.loginReady` stage 와 동일한 컴포넌트를 사용해 두 화면 간 시각적 일관성을 보장한다.
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

            AuthLogoBlock()
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

            Spacer()

            LoginActionStack(
                isLoading: viewModel.loginState.isLoading,
                onKakaoTap: { Task { await viewModel.loginWithKakao() } },
                onAppleTap: { viewModel.loginWithApple() },
                onGoogleTap: { Task { await viewModel.loginWithGoogle() } },
                onSupportTap: {
                    kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
                }
            )
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.bottom, DefaultConstant.defaultSafeBottom)
        }
    }
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

    func executeGoogle(idToken: String) async throws -> OAuthLoginResult {
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
