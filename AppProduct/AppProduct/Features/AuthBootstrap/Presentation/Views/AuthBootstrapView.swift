//
//  AuthBootstrapView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/26/26.
//
//  앱 진입 시 자동 chromaticLens 시네마틱을 한 번 재생하면서 인증 부트스트랩을 병렬 수행하고,
//  로그인 단계로 진입해야 할 경우 **같은 화면 안에서** 로고를 위로 슬라이드하며 로그인 버튼들을
//  등장시키는 단일 진입 화면.
//
//  ## 동작
//
//  - mount 직후 `refractiveCinematic` modifier 가 3-phase (워터마크 → bloom → collapse) 시퀀스를
//    2.3s 동안 재생한다. dwell(정점 정지) 단계 없이 한 keyframe timeline 으로 흘러 멈춤 느낌 없음.
//  - 동시에 `bootstrapViewModel.checkAuthStatus()` 가 background 에서 토큰/프로필/버전 검사를
//    수행한다.
//  - 시네마틱 최소 시간(2.3s) + 인증 완료 둘 다 만족하면 결과에 따라 분기한다.
//    - `.approved` / `.pendingApproval` → AppFlow 로 외부 화면 라우팅
//    - `.notLoggedIn` → **`stage` 를 `.loginReady` 로 전환** → 같은 화면 안에서 layout 이
//      `withAnimation` 으로 morph (로고가 위로 슬라이드, LoginActionStack 이 아래에서 등장)
//  - 사용자가 로그인 버튼을 누르면 내부 `LoginViewModel` 이 인증을 진행하고, 결과 `destination`
//    변경 시 AppFlow 로 외부 화면 라우팅.
//
//  ## 왜 한 화면인가
//
//  AuthBootstrapView 와 LoginView 가 별도 View 였을 때는 둘 사이를 SwiftUI `rootTransition`
//  (opacity + move) 으로만 연결할 수 있어 "lens 가 다 사라지고 화면이 잠시 멈추는" dead-time
//  이 생겼다. 한 View 안에서 `stage` enum 으로 layout 을 변경하면 SwiftUI 가 동일 view tree
//  의 spacer/component 위치를 보간해, 로고 morph + 버튼 등장이 한 동작으로 흘러간다.
//

import SwiftUI

struct AuthBootstrapView: View {

    // MARK: - Stage

    /// 진입 화면 단계
    private enum Stage: Equatable {
        /// 시네마틱 재생 중. 로고가 화면 정중앙.
        case cinematic
        /// 시네마틱 종료 + 자동 로그인 실패. 로고가 위쪽으로 morph, 하단에 LoginActionStack 등장.
        case loginReady
    }

    // MARK: - Property

    @State private var bootstrapViewModel: AuthBootstrapViewModel
    @State private var loginViewModel: LoginViewModel
    @State private var stage: Stage = .cinematic
    @State private var navPath: [NavigationDestination] = []

    @Environment(\.appFlow) private var appFlow
    @Environment(ErrorHandler.self) private var errorHandler

    /// 카카오톡 UMC 문의 채널 연동 매니저
    private let kakaoPlusManager: KakaoPlusManager = .init()

    private enum Constants {
        /// 시네마틱 종료 시점. `RefractiveCinematic` 시퀀스 총 길이(preDelay 0.4 + bloom 1.0 +
        /// collapse 0.9 = 2.3s)와 일치한다. 인증이 더 빨리 끝나도 이 시간만큼은 시네마틱을
        /// 유지하고, 그 후 morph 트리거. **이 값과 refractiveCinematic 의 duration 합은 항상
        /// 동기화해야 한다** — 어긋나면 라우팅이 collapse 도중 끊고 들어온다.
        static let cinematicTotalDuration: TimeInterval = 2.3
        /// 인증 최대 대기 시간. 초과 시 `.notLoggedIn` 가정 후 loginReady morph.
        static let authTimeout: TimeInterval = 3.0
        /// stage 전환 애니메이션 시간 — 로고 위로 슬라이드 + actionStack 등장 morph.
        static let morphDuration: TimeInterval = 0.55
    }

    // MARK: - Init

    init(
        networkClient: NetworkClient,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        loginUseCase: LoginUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self._bootstrapViewModel = .init(
            wrappedValue: AuthBootstrapViewModel(
                networkClient: networkClient,
                fetchMyProfileUseCase: fetchMyProfileUseCase,
                tokenStore: tokenStore
            )
        )
        self._loginViewModel = .init(
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
            contentLayout
                .refractiveCinematic()
                .alertPrompt(item: $bootstrapViewModel.updateAlertPrompt)
                .task { await runBootstrap() }
                .navigationDestination(for: NavigationDestination.self) { destination in
                    NavigationRoutingView(destination: destination)
                }
        }
        .onChange(of: loginViewModel.destination) { _, newDestination in
            handleLoginDestination(newDestination)
        }
    }

    // MARK: - Layout

    private var contentLayout: some View {
        VStack(spacing: .zero) {
            Spacer()

            AuthLogoBlock()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

            Spacer()

            if stage == .loginReady {
                LoginActionStack(
                    isLoading: loginViewModel.loginState.isLoading,
                    onKakaoTap: { Task { await loginViewModel.loginWithKakao() } },
                    onAppleTap: { loginViewModel.loginWithApple() },
                    onGoogleTap: { Task { await loginViewModel.loginWithGoogle() } },
                    onSupportTap: {
                        kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
                    }
                )
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .padding(.bottom, DefaultConstant.defaultSafeBottom)
                .transition(
                    .opacity.combined(with: .move(edge: .bottom))
                )
            }
        }
        .animation(.easeInOut(duration: Constants.morphDuration), value: stage)
    }

    // MARK: - Bootstrap

    /// 시네마틱 최소 시간과 인증 검사를 병렬로 진행하고, 둘 다 완료되면 라우팅 or morph.
    @MainActor
    private func runBootstrap() async {
        async let minimumWait: Void = sleepSeconds(Constants.cinematicTotalDuration)
        async let authTask: Void = runAuthWithTimeout()

        _ = await (minimumWait, authTask)

        guard !bootstrapViewModel.needsUpdate else { return }
        route()
    }

    /// 인증 검사를 타임아웃 안에서 실행한다. 타임아웃 시 ViewModel 은 `.notLoggedIn` 상태를 유지한다.
    @MainActor
    private func runAuthWithTimeout() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await bootstrapViewModel.checkAuthStatus()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(Constants.authTimeout))
            }
            _ = await group.next()
            group.cancelAll()
        }
    }

    private func sleepSeconds(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// 인증 결과에 따라 외부 화면으로 라우팅하거나, 같은 화면 안에서 loginReady stage 로 morph.
    private func route() {
        switch bootstrapViewModel.authStatus {
        case .approved:
            appFlow.showMain()
        case .pendingApproval:
            appFlow.showPendingApproval()
        case .notLoggedIn:
            stage = .loginReady
        }
    }

    /// LoginViewModel 의 destination 변경을 AppFlow 라우팅으로 변환.
    private func handleLoginDestination(_ newDestination: LoginDestination?) {
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
