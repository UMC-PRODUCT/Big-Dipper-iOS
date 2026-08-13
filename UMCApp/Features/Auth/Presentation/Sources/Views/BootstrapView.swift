//
//  BootstrapView.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/8/26.
//
//  앱 진입 시 자동 chromaticLens 시네마틱을 한 번 재생하면서 인증 부트스트랩을 병렬 수행하고,
//  로그인 단계로 진입해야 할 경우 **같은 화면 안에서** 로고를 위로 슬라이드하며 로그인 버튼들을
//  등장시키는 단일 진입 화면.
//
//  ## 동작
//
//  - mount 직후 `refractiveCinematic` modifier 가 3-phase (정적 로고 → bloom → collapse) 시퀀스를
//    2.3s 동안 재생한다. dwell(정점 정지) 단계 없이 한 keyframe timeline 으로 흘러 멈춤 느낌 없음.
//  - 동시에 `bootstrapViewModel.resolveAuthStatus()` 가 background 에서 토큰/프로필 검사를
//    수행한다.
//  - 시네마틱 최소 시간(2.3s) + 인증 완료 둘 다 만족하면 결과에 따라 분기한다.
//    - `.approved` / `.pendingApproval` → AppFlow 로 외부 화면 라우팅
//    - `.notLoggedIn` → **`stage` 를 `.loginReady` 로 전환** → 같은 화면 안에서 layout 이
//      `withAnimation` 으로 morph (로고가 위로 슬라이드, LoginActionStack 이 아래에서 등장)
//    - `.networkUnavailable` → **`stage` 를 `.networkUnavailable` 로 전환** → 재시도 안내를
//      노출한다. 토큰이 살아있는데 서버에 닿지 못한 것뿐이므로 로그인 화면으로 내리지 않는다.
//  - 사용자가 소셜 로그인 버튼을 누르면 내부 `LoginViewModel` 이 인증을 진행하고, 결과 상태
//    변경 시 AppFlow 로 외부 화면 라우팅.
//  - UMC 계정(ID/PW) 로그인은 `LoginView` 와 동일하게 `EmailLoginView` 를 push 한다 (#943).
//
//  ## 왜 한 화면인가
//
//  BootstrapView 와 LoginView 를 AppFlow 상태 전환(cross-fade)으로만 연결하면 "lens 가 다
//  사라지고 화면이 잠시 멈추는" dead-time 이 생긴다. 한 View 안에서 `stage` enum 으로 layout 을
//  변경하면 SwiftUI 가 동일 view tree 의 spacer/component 위치를 보간해, 로고 morph + 버튼
//  등장이 한 동작으로 흘러간다. `.loginReady` layout 은 `LoginView` 와 동일한 구조라 시각적
//  일관성이 유지된다 (별도 `LoginView` 는 로그아웃 복귀 경로에서 계속 사용).
//

import AuthDomain
import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreNetwork
import CoreUIComponents
import SwiftUI
import UMCFoundation

public struct BootstrapView: View {

    // MARK: - Stage

    /// 진입 화면 단계
    private enum Stage: Equatable {
        /// 시네마틱 재생 중. 로고가 화면 정중앙.
        case cinematic
        /// 시네마틱 종료 + 자동 로그인 실패. 로고가 위쪽으로 morph, 하단에 LoginActionStack 등장.
        case loginReady
        /// 전송 계층 실패로 인증 판정 불가. 로그인 화면 대신 재시도 안내를 노출.
        case networkUnavailable
    }

    // MARK: - Property

    @State private var bootstrapViewModel: BootstrapViewModel
    @State private var loginViewModel: LoginViewModel
    @State private var stage: Stage = .cinematic
    /// 슬로건 reveal 투명도(0~1). preDelay 동안 0 (이미지 로고만 보임) → bloom 동안 0 → 1
    /// (lens 가 비춰지면서 슬로건이 차오름) → collapse 동안 1 유지. `revealSlogan()` 가 컨트롤.
    @State private var sloganOpacity: Double = 0
    @State private var isEmailLoginPresented = false
    @State private var isRetryingAuth = false

    @Environment(\.appFlow) private var appFlow

    /// 이메일 로그인 화면을 push할 때 그대로 전달하기 위해 보관한다.
    private let container: DIContainer
    private let errorHandler: ErrorHandler
    private let kakaoPlusManager = KakaoPlusManager()

    private enum Constants {
        /// 시네마틱 종료 시점. `RefractiveCinematic` 시퀀스 총 길이(preDelay 0.4 + bloom 1.0 +
        /// collapse 0.9 = 2.3s)와 일치한다. 인증이 더 빨리 끝나도 이 시간만큼은 시네마틱을
        /// 유지하고, 그 후 morph 트리거. **이 값과 refractiveCinematic 의 duration 합은 항상
        /// 동기화해야 한다** — 어긋나면 라우팅이 collapse 도중 끊고 들어온다.
        static let cinematicTotalDuration: TimeInterval = 2.3
        /// 인증 최대 대기 시간. 초과 시 `.networkUnavailable` 로 간주해 재시도 안내를 노출한다.
        /// 응답이 늦다는 사실만으로는 세션 무효를 단정할 수 없어 로그인 화면으로 내리지 않는다.
        static let authTimeout: TimeInterval = 3.0
        /// stage 전환 애니메이션 시간 — 로고 위로 슬라이드 + actionStack 등장 morph.
        static let morphDuration: TimeInterval = 0.55
        /// 슬로건 reveal 시작 지연. RefractiveCinematic 의 preDelay 와 동기화 — preDelay 동안
        /// 이미지 로고만 보이고 슬로건은 숨김.
        static let sloganRevealDelay: TimeInterval = 0.4
        /// 슬로건 reveal 애니메이션 시간. RefractiveCinematic 의 bloomDuration 과 동기화 —
        /// lens 가 펴지는 동안 슬로건이 0 → 1 로 차올라 "lens 안에서 슬로건이 보이며 등장" 효과.
        static let sloganRevealDuration: TimeInterval = 1.0
        static let networkGuideTitle = "네트워크 연결을 확인해 주세요"
        static let networkGuideSystemImage = "wifi.exclamationmark"
        static let networkGuideDescription = """
        인터넷에 연결한 뒤 다시 시도해 주세요.
        로그인 정보는 그대로 유지됩니다.
        """
    }

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
        _bootstrapViewModel = State(initialValue: BootstrapViewModel(container: container))
        _loginViewModel = State(
            initialValue: LoginViewModel(container: container, errorHandler: errorHandler)
        )
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            contentLayout
                .refractiveCinematic()
                // 루트에는 표시할 네비게이션 바가 없다. 숨기지 않으면 빈 바 높이만큼 safe area 가
                // 줄어 로고(=lens 중심)가 아래로 밀린다 — 시네마틱 중앙 정렬이 어긋난다.
                .toolbarVisibility(.hidden, for: .navigationBar)
                .task { await runBootstrap() }
                .task { await revealSlogan() }
                .onChange(of: loginViewModel.loginState) { _, newState in
                    handle(newState: newState)
                }
                .onChange(of: loginViewModel.signUpDestination) { _, newDestination in
                    handle(signUpDestination: newDestination)
                }
                .navigationDestination(isPresented: $isEmailLoginPresented) {
                    EmailLoginView(container: container, errorHandler: errorHandler)
                }
        }
    }

    // MARK: - Layout

    /// `.loginReady` 상태의 layout 은 `LoginView` 의 body 와 동일한 구조를 유지해야 한다 —
    /// 로그아웃 복귀(`LoginView`) 화면과 시각적으로 일치시키기 위함.
    private var contentLayout: some View {
        VStack(spacing: .zero) {
            Spacer()

            AuthLogoBlock(sloganOpacity: sloganOpacity)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

            Spacer()

            switch stage {
            case .cinematic:
                EmptyView()

            case .loginReady:
                LoginActionStack(
                    isLoading: loginViewModel.loginState.isLoading,
                    onKakaoTap: { Task { await loginViewModel.loginWithKakao() } },
                    onAppleTap: { loginViewModel.loginWithApple() },
                    onGoogleTap: { Task { await loginViewModel.loginWithGoogle() } },
                    onEmailTap: { isEmailLoginPresented = true },
                    onSupportTap: {
                        kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
                    }
                )
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .padding(.bottom, DefaultConstant.defaultSafeBottom)
                .transition(
                    .opacity.combined(with: .move(edge: .bottom))
                )

            case .networkUnavailable:
                RetryContentUnavailableView(
                    title: Constants.networkGuideTitle,
                    systemImage: Constants.networkGuideSystemImage,
                    description: Constants.networkGuideDescription,
                    isRetrying: isRetryingAuth,
                    retryAction: { await retryAuthResolution() }
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

    /// 슬로건 reveal — preDelay 동안 숨겨두고 (sloganOpacity = 0), bloom 시작 시점에 0 → 1 로
    /// ease-in-out 차오르게 한다. RefractiveCinematic 의 lens 가 펴지는 동안 슬로건이 lens
    /// 안에서 동시에 reveal 되어 "lens 가 비춰지면서 슬로건이 보이는" 시네마틱 연출이 완성된다.
    ///
    /// 별도 `.task` 로 띄워 `runBootstrap` 의 인증 결과와 무관하게 timeline 을 따라가게 한다 —
    /// 인증이 빨라서 일찍 morph 가 트리거돼도 슬로건은 이미 reveal 된 상태로 인계.
    @MainActor
    private func revealSlogan() async {
        try? await Task.sleep(for: .seconds(Constants.sloganRevealDelay))
        withAnimation(.easeInOut(duration: Constants.sloganRevealDuration)) {
            sloganOpacity = 1.0
        }
    }

    /// 시네마틱 최소 시간과 인증 검사를 병렬로 진행하고, 둘 다 완료되면 라우팅 or morph.
    @MainActor
    private func runBootstrap() async {
        #if DEBUG
        if Self.isMockAuthBypassEnabled {
            appFlow.showMain()
            return
        }
        #endif

        async let minimumWait: Void = sleepSeconds(Constants.cinematicTotalDuration)
        async let authStatus = resolveAuthStatusWithTimeout()

        let (_, resolvedStatus) = await (minimumWait, authStatus)
        route(for: resolvedStatus)
    }

    /// 네트워크 안내 뷰의 재시도 — 시네마틱은 이미 끝났으므로 인증 판정만 다시 수행한다.
    ///
    /// `runBootstrap()` 을 재호출하면 최소 대기(2.3s)가 다시 걸려 사용자가 시네마틱을 한 번 더
    /// 기다리게 되므로, 재시도 경로에서는 대기 없이 `resolveAuthStatusWithTimeout()` 만 돌린다.
    @MainActor
    private func retryAuthResolution() async {
        guard !isRetryingAuth else { return }
        isRetryingAuth = true
        defer { isRetryingAuth = false }
        route(for: await resolveAuthStatusWithTimeout())
    }

    /// 인증 검사를 타임아웃 안에서 실행한다. 타임아웃이 먼저 끝나면 `.networkUnavailable` 로
    /// 간주해 시네마틱이 무한정 인증을 기다리며 화면이 멈추는 상황을 방지한다.
    @MainActor
    private func resolveAuthStatusWithTimeout() async -> AuthBootstrapStatus {
        await withTaskGroup(of: AuthBootstrapStatus?.self) { group in
            group.addTask { @MainActor in
                await bootstrapViewModel.resolveAuthStatus()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(Constants.authTimeout))
                return nil
            }
            let firstResult = await group.next() ?? nil
            group.cancelAll()
            return firstResult ?? .networkUnavailable
        }
    }

    private func sleepSeconds(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// 인증 결과에 따라 외부 화면으로 라우팅하거나, 같은 화면 안에서 loginReady stage 로 morph.
    private func route(for status: AuthBootstrapStatus) {
        switch status {
        case .approved:
            appFlow.showMain()
        case .pendingApproval:
            appFlow.showPendingApproval()
        case .notLoggedIn:
            stage = .loginReady
        case .networkUnavailable:
            stage = .networkUnavailable
        }
    }

    // MARK: - Login Handling

    /// 내장 `LoginViewModel` 의 로그인 결과를 AppFlow 라우팅으로 변환 (`LoginView` 와 동일 규칙).
    private func handle(newState: Loadable<Profile>) {
        if case .loaded = newState {
            appFlow.showMain()
        }
        if newState == .failed(.auth(.pendingApproval)) {
            appFlow.showPendingApproval()
        }
    }

    private func handle(signUpDestination: SignUpDestination?) {
        guard let signUpDestination else { return }
        appFlow.showSignUp(
            signUpDestination.verificationToken,
            signUpDestination.email,
            signUpDestination.fullName,
            signUpDestination.postRegisterLoginContext
        )
    }

    #if DEBUG
    /// `MOCK_AUTH_BYPASS=1` 환경변수(스킴의 Arguments > Environment Variables)를 설정하면
    /// 실제 토큰/서버 상태와 무관하게 즉시 메인으로 진입한다. 시네마틱을 기다리지 않고 Home을
    /// 단독으로 테스트하기 위한 개발 전용 우회 경로다 (절대규칙 #5).
    private static var isMockAuthBypassEnabled: Bool {
        ProcessInfo.processInfo.environment["MOCK_AUTH_BYPASS"] == "1"
    }
    #endif
}
