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
        VStack {
            Spacer()
            TopLogo()
            Spacer()
            BottomSocialBtns(
                isLoading: viewModel.loginState.isLoading,
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
/// UMC 로고와 설명 텍스트를 세로로 배치합니다.
/// Equatable 준수로 불필요한 렌더링을 방지합니다.
fileprivate struct TopLogo: View, Equatable {

    // MARK: - Constant

    /// 레이아웃 및 텍스트 상수
    private enum Constants {
        /// 로고 설명 문구
        static let logoDescrip: String = "UMC 활동을 더 편하게 관리해보세요"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing4, content: {
            Logo()
            Text(Constants.logoDescrip)
                .appFont(.body, weight: .medium, color: .grey600)
        })
    }
}

// MARK: - BottomSocialBtns

/// 하단 소셜 로그인 버튼 영역
fileprivate struct BottomSocialBtns: View, Equatable {

    // MARK: - Property

    let isLoading: Bool
    var onKakaoTapped: () -> Void
    var onAppleTapped: () -> Void

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isLoading == rhs.isLoading
    }

    // MARK: - Body

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                socialButtonList
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, DefaultConstant.defaultSafeBottom)
    }

    // MARK: - Subviews

    private var socialButtonList: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ForEach(SocialType.appConnectableCases, id: \.self) { btn in
                socialButton(for: btn)
            }
        }
    }

    private func socialButton(for type: SocialType) -> some View {
        Button(action: { handleSocialTap(type) }) {
            type.image
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .glassEffect(.regular.interactive())
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
