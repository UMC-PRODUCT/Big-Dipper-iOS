import AuthPresentation
import CoreDesignSystem
import CoreDI
import CoreNetwork
import HomePresentation
import SwiftUI
import UMCFoundation

/// 앱 루트 화면.
///
/// `AppFlowViewModel`의 상태에 따라 Bootstrap / Login / Main(탭 셸)을 스위칭한다.
/// 탭 셸·실제 로그인 화면은 후속 이슈(#910, #912)에서 이 스위치의 각 분기를 교체한다.
struct AppRootView: View {

    // MARK: - Property

    @State private var viewModel = AppFlowViewModel()
    @Environment(\.di) private var di

    // MARK: - Body

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .bootstrap:
                BootstrapPlaceholderView()

            case .login:
                AuthFeatureView()

            case .main:
                HomeFeatureView()
            }
        }
        .animation(.easeInOut(duration: DefaultConstant.animationTime), value: viewModel.state)
        .environment(\.appFlow, viewModel.appFlow)
        .onReceive(
            NotificationCenter.default.publisher(for: .authSessionExpired)
        ) { _ in
            handleAuthSessionExpired()
        }
        #if DEBUG
        .overlay(alignment: .bottom) {
            debugFlowSwitcher
        }
        #endif
    }

    // MARK: - Function

    /// 세션 만료 시 토큰 삭제 → DI 캐시 초기화 → 로그인 화면 전환을 수행한다.
    ///
    /// - Note: 토큰 삭제는 `NetworkClient`가 `actor`라 비동기이므로 `Task`로 발행하고,
    ///   캐시 초기화·화면 전환은 그 완료를 기다리지 않고 즉시 진행한다(레거시
    ///   `AppProductApp.handleAuthSessionExpired()`와 동일한 순서).
    private func handleAuthSessionExpired() {
        Task {
            try? await di.resolve(NetworkClient.self).logout()
        }
        di.resetCache()
        viewModel.logout()
    }

    #if DEBUG
    // MARK: - Debug

    /// 상태머신 강제 전환 확인용 디버그 컨트롤. 릴리스 빌드에는 포함되지 않는다.
    private var debugFlowSwitcher: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Button("Bootstrap") { viewModel.showBootstrap() }
            Button("Login") { viewModel.showLogin() }
            Button("Main") { viewModel.showMain() }
        }
        .buttonStyle(.bordered)
        .padding(.bottom, DefaultConstant.defaultSafeBottom)
    }
    #endif
}

/// Bootstrap 상태의 최소 자리표시 화면.
///
/// 자동 로그인 판단 로직은 후속 이슈(#911)에서 이 자리에 연결된다.
private struct BootstrapPlaceholderView: View {
    var body: some View {
        ProgressView()
    }
}
