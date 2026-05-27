//
//  AuthBootstrapView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/26/26.
//
//  앱 진입 시 자동 chromaticLens 시네마틱을 한 번 재생하면서 인증 부트스트랩을 병렬 수행하는 화면.
//
//  ## 동작
//
//  - mount 직후 `refractiveCinematic` modifier 가 4-phase (정적 로고 → bloom → dwell → collapse)
//    시퀀스를 1.8s 동안 재생한다.
//  - 동시에 `viewModel.checkAuthStatus()` 가 background 에서 토큰/프로필/버전 검사를 수행한다.
//  - 시네마틱 최소 시간(1.65s) + 인증 완료 둘 다 만족하면 라우팅한다 — collapse 가 90% 진행된
//    시점에서 routing 을 시작해, 마지막 lens 잔재가 사라지는 fade-out 과 LoginView 의 fade-in
//    이 cross-fade 되도록 한다 (대기 buffer 가 만드는 "잠시 멈춤" 느낌을 제거).
//

import SwiftUI

struct AuthBootstrapView: View {

    // MARK: - Property

    @State private var viewModel: AuthBootstrapViewModel
    @Environment(\.appFlow) private var appFlow

    private enum Constants {
        /// 시네마틱이 보이는 최소 시간. 인증이 더 빨리 끝나도 이 시간만큼은 시각 효과를 유지한다.
        /// `RefractiveCinematic` 시퀀스 총 길이(1.8s) 의 약 90% 시점 — collapse 가 거의 끝났지만
        /// 마지막 lens 잔재가 fade-out 중인 순간에 routing 을 시작해, 그 잔재와 LoginView 의
        /// fade-in(rootTransition, 0.28s) 이 cross-fade 되도록 한다. 시각적 dead-time 제거.
        static let minimumCinematicDuration: TimeInterval = 1.65
        /// 인증 최대 대기 시간. 초과 시 `.notLoggedIn` 가정 후 LoginView 진입.
        static let authTimeout: TimeInterval = 3.0
    }

    // MARK: - Init

    init(
        networkClient: NetworkClient,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore
    ) {
        self._viewModel = .init(
            wrappedValue: AuthBootstrapViewModel(
                networkClient: networkClient,
                fetchMyProfileUseCase: fetchMyProfileUseCase,
                tokenStore: tokenStore
            )
        )
    }

    // MARK: - Body

    var body: some View {
        contentLayout
            .refractiveCinematic()
            .alertPrompt(item: $viewModel.updateAlertPrompt)
            .task { await runBootstrap() }
    }

    // MARK: - Layout

    private var contentLayout: some View {
        VStack(spacing: .zero) {
            Spacer()
            AuthLogoBlock()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            Spacer()
        }
    }

    // MARK: - Bootstrap

    /// 시네마틱 최소 시간과 인증 검사를 병렬로 진행하고, 둘 다 완료되면 라우팅한다.
    @MainActor
    private func runBootstrap() async {
        async let minimumWait: Void = sleepSeconds(Constants.minimumCinematicDuration)
        async let authTask: Void = runAuthWithTimeout()

        _ = await (minimumWait, authTask)

        guard !viewModel.needsUpdate else { return }
        route()
    }

    /// 인증 검사를 타임아웃 안에서 실행한다. 타임아웃 시 ViewModel 은 `.notLoggedIn` 상태를 유지한다.
    @MainActor
    private func runAuthWithTimeout() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await viewModel.checkAuthStatus()
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

    private func route() {
        switch viewModel.authStatus {
        case .approved:
            appFlow.showMain()
        case .pendingApproval:
            appFlow.showPendingApproval()
        case .notLoggedIn:
            appFlow.showLogin()
        }
    }
}
