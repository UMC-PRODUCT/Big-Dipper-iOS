//
//  AppRootView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import AuthPresentation
import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreNetwork
#if DEBUG
import MaintenanceData
#endif
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
    private func handleAuthSessionExpired() {
        let networkClient = di.resolve(NetworkClient.self)
        let memberProfileRepository = di.resolveIfRegistered(MemberProfileRepositoryProtocol.self)
        di.resolve(UserSessionManager.self).reset()
        di.resetCache()
        viewModel.logout()
        Task {
            try? await networkClient.logout()
        }
        Task {
            await memberProfileRepository?.invalidateCache()
        }
    }

    #if DEBUG
    // MARK: - Debug

    /// `MaintenanceDebugOverride`로 점검·강제 업데이트 오버레이가 강제 ON인 동안에는
    /// `true`.
    ///
    /// - Note: 이 상태에서 `SignUp(ID/PW)`·`Reset PW` 버튼으로 디버그
    ///   `fullScreenCover`를 켜면, 앱 루트(`UMCAppApp`)의 점검 오버레이
    ///   `fullScreenCover`와 이 화면의 `fullScreenCover`가 동시에 표시를 시도해
    ///   SwiftUI 프레젠테이션이 깨진다. 두 오버레이가 같은 화면에 동시에 뜰 일이
    ///   없도록 진입 자체를 막는다.
    private var isMaintenanceOverlayDebugForced: Bool {
        MaintenanceDebugOverride.isMaintenanceForced
            || MaintenanceDebugOverride.isForceUpdateForced
    }

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
            Button(
                isMaintenanceOverlayDebugForced
                    ? "SignUp(ID/PW) — 점검 오버레이 중 비활성"
                    : "SignUp(ID/PW)"
            ) {
                isDebugSignUpByIdPwPresented = true
            }
            .disabled(isMaintenanceOverlayDebugForced)
            Button(
                isMaintenanceOverlayDebugForced
                    ? "Reset PW — 점검 오버레이 중 비활성"
                    : "Reset PW"
            ) {
                isDebugResetPasswordPresented = true
            }
            .disabled(isMaintenanceOverlayDebugForced)
        }
        .buttonStyle(.bordered)
        .padding(.bottom, DefaultConstant.defaultSafeBottom)
    }
    #endif
}
