import AuthDomain
import CoreDI
import Foundation
import SwiftUI
import UMCFoundation

/// 부트스트랩 화면 — 앱 진입 시 토큰/프로필을 확인해 로그인·메인 여부를 판단하는 동안 표시된다.
///
/// 시네마틱(Metal 셰이더) 연출은 포함하지 않는 최소 화면이다.
public struct BootstrapView: View {

    // MARK: - Property

    @State private var viewModel: BootstrapViewModel
    @Environment(\.appFlow) private var appFlow

    // MARK: - Init

    public init(container: DIContainer) {
        _viewModel = State(initialValue: BootstrapViewModel(container: container))
    }

    // MARK: - Body

    public var body: some View {
        ProgressView()
            .task {
                await checkAuthStatus()
            }
    }

    // MARK: - Function

    private func checkAuthStatus() async {
        #if DEBUG
        if Self.isMockAuthBypassEnabled {
            appFlow.showMain()
            return
        }
        #endif

        switch await viewModel.resolveAuthStatus() {
        case .approved:
            appFlow.showMain()
        case .pendingApproval:
            appFlow.showPendingApproval()
        case .notLoggedIn:
            appFlow.showLogin()
        }
    }

    #if DEBUG
    /// `MOCK_AUTH_BYPASS=1` 환경변수(스킴의 Arguments > Environment Variables)를 설정하면
    /// 실제 토큰/서버 상태와 무관하게 즉시 메인으로 진입한다. 로그인 화면이 구현되기 전
    /// Home을 단독으로 테스트하기 위한 개발 전용 우회 경로다 (절대규칙 #5).
    private static var isMockAuthBypassEnabled: Bool {
        ProcessInfo.processInfo.environment["MOCK_AUTH_BYPASS"] == "1"
    }
    #endif
}
