import AuthPresentation
import CoreDesignSystem
import CoreDI
import CoreNetwork
import SwiftUI
import UMCFoundation

/// 앱 루트 화면.
///
/// `AppFlowViewModel`의 상태에 따라 Bootstrap / Login / SignUp / Main(탭 셸)을 스위칭한다.
struct AppRootView: View {

    // MARK: - Property

    @State private var viewModel = AppFlowViewModel()
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler
    #if DEBUG
    @State private var isDebugSignUpByIdPwPresented = false
    // TODO: [#943] ID/PW 로그인 화면이 이식되면 그 화면의 "비밀번호 찾기" 링크로 대체하고
    // 이 DEBUG 진입점은 제거한다.
    @State private var isDebugResetPasswordPresented = false
    #endif

    // MARK: - Body

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .bootstrap:
                BootstrapView(container: di)

            case .login:
                LoginView(container: di, errorHandler: errorHandler)

            case .signUp(let verificationToken, let email, let fullName, let context):
                SignUpView(
                    container: di,
                    errorHandler: errorHandler,
                    verificationToken: verificationToken,
                    initialEmail: email,
                    initialFullName: fullName,
                    postRegisterLoginContext: context
                )

            case .pendingApproval:
                FailedVerificationUMC(container: di, errorHandler: errorHandler)

            case .main:
                RootTabView()
            }
        }
        .animation(.easeInOut(duration: DefaultConstant.animationTime), value: viewModel.state)
        .environment(\.appFlow, viewModel.appFlow)
        .onReceive(
            NotificationCenter.default.publisher(for: .authSessionExpired)
        ) { _ in
            handleAuthSessionExpired()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .navigateToPendingApproval)
        ) { _ in
            viewModel.showPendingApproval()
        }
        #if DEBUG
        .overlay(alignment: .bottom) {
            debugFlowSwitcher
        }
        .fullScreenCover(isPresented: $isDebugSignUpByIdPwPresented) {
            SignUpByIdPwView(container: di, errorHandler: errorHandler)
        }
        .fullScreenCover(isPresented: $isDebugResetPasswordPresented) {
            ResetPasswordView(container: di, errorHandler: errorHandler)
        }
        #endif
    }

    // MARK: - Function

    /// 세션 만료 시 DI 캐시 초기화 → 로그인 화면 전환 → (비동기) 토큰 삭제를 수행한다.
    ///
    /// - Note: `resetCache()`보다 먼저 `NetworkClient` 참조를 동기적으로 확보한다.
    ///   순서를 바꾸면 `Task` 내부의 `resolve`가 캐시 미스로 새 인스턴스를 생성해
    ///   기존 인스턴스의 `refreshTask`가 취소되지 않고, `DIContainer`는 락이 없는
    ///   `final class`라 캐시 딕셔너리에 대한 동시 접근 크래시 위험도 있다. 토큰 삭제
    ///   자체는 `NetworkClient`가 `actor`라 비동기이므로 `Task`로 발행하고 완료를
    ///   기다리지 않는다.
    private func handleAuthSessionExpired() {
        let networkClient = di.resolve(NetworkClient.self)
        di.resetCache()
        viewModel.logout()
        Task {
            try? await networkClient.logout()
        }
    }

    #if DEBUG
    // MARK: - Debug

    /// 상태머신 강제 전환 확인용 디버그 컨트롤. 릴리스 빌드에는 포함되지 않는다.
    ///
    /// - Note: 이메일(ID/PW) 가입 화면(`SignUpByIdPwView`)과 비밀번호 재설정 화면
    ///   (`ResetPasswordView`)은 프로덕션 네비게이션 배선이 아직 없다(각각 Q1, #943 참고 —
    ///   후속 이슈에서 연결). 그 전까지 QA/리뷰어용 임시 진입점만 제공한다.
    private var debugFlowSwitcher: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Button("Bootstrap") { viewModel.showBootstrap() }
            Button("Login") { viewModel.showLogin() }
            Button("Main") { viewModel.showMain() }
            Button("SignUp(ID/PW)") { isDebugSignUpByIdPwPresented = true }
            Button("Reset PW") { isDebugResetPasswordPresented = true }
        }
        .buttonStyle(.bordered)
        .padding(.bottom, DefaultConstant.defaultSafeBottom)
    }
    #endif
}
