import AuthPresentation
import CoreDesignSystem
import CoreDI
import CoreNetwork
import SwiftUI
import UMCFoundation

/// 앱 루트 화면.
///
/// `AppFlowViewModel`의 상태에 따라 Bootstrap / Login / Main(탭 셸)을 스위칭한다.
/// 실제 로그인 화면은 후속 이슈(#912)에서 이 스위치의 분기를 교체한다.
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
        #if DEBUG
        .overlay(alignment: .bottom) {
            debugFlowSwitcher
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
