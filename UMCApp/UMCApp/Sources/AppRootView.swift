//
//  AppRootView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import AuthPresentation
import CommunityDomain
import CoreDesignSystem
import CoreDI
import CoreDomain
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

    // MARK: - Body

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .bootstrap:
                BootstrapView(container: di, errorHandler: errorHandler)

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
    }

    // MARK: - Function

    /// 세션 만료 시 세션 역할 상태 초기화 → DI 캐시 초기화 → 로그인 화면 전환 →
    /// (비동기) 토큰 삭제를 수행한다.
    ///
    /// - Note: `resetCache()`보다 먼저 `NetworkClient`/정본 프로필 캐시 참조를 동기적으로
    ///   확보한다. 순서를 바꾸면 `Task` 내부의 `resolve`가 캐시 미스로 새 인스턴스를 생성해
    ///   기존 인스턴스의 `refreshTask`가 취소되지 않고, `DIContainer`는 락이 없는
    ///   `final class`라 캐시 딕셔너리에 대한 동시 접근 크래시 위험도 있다. 토큰 삭제와
    ///   프로필 캐시 무효화 자체는 각각 `actor`라 비동기이므로 `Task`로 발행하고 완료를
    ///   기다리지 않는다. `resetCache()`가 인스턴스 자체를 폐기해도, 세션 만료 시점에
    ///   진행 중이던 프로필 조회가 있었다면 그 결과가 뒤늦게 캐시를 채우지 않도록
    ///   명시적으로 `invalidateCache()`를 함께 호출한다.
    ///
    /// - Note: STOMP 연결은 `resetCache()`가 참조를 버려도 펌프 Task가 자기 클라이언트를
    ///   강참조해 살아남는다. 그 orphan은 생성 시점에 붙잡은 구 `TokenStore`의 인메모리 캐시를
    ///   그대로 써서 만료된 세션의 토큰으로 재연결을 계속하므로, 참조를 버리기 전에 반드시
    ///   `stop()`을 예약한다. 아직 시작하지 않은 연결에는 no-op이고, 한 번도 만들어지지
    ///   않았다면 `resolveIfCached`가 nil을 반환해 새 인스턴스를 만들지 않는다.
    private func handleAuthSessionExpired() {
        let networkClient = di.resolve(NetworkClient.self)
        let memberProfileRepository = di.resolveIfRegistered(MemberProfileRepositoryProtocol.self)
        let communityRealtime = di.resolveIfCached(CommunityThreadRealtimeProtocol.self)
        di.resolve(UserSessionManager.self).reset()
        di.resetCache()
        viewModel.logout()
        Task {
            try? await networkClient.logout()
        }
        Task {
            await memberProfileRepository?.invalidateCache()
        }
        Task {
            await communityRealtime?.stop()
        }
    }
}
