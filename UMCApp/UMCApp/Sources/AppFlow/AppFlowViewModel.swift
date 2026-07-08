import Foundation
import UMCFoundation

/// 앱 생명주기 전역 상태머신.
///
/// 절대규칙 #1의 명시적 예외(앱 생명주기 전역 관리자)로 `@Observable`을 사용한다.
/// `AppRootView`가 이 ViewModel을 소유하고, 하위 Feature에는 `AppFlow` 환경값을 통해서만
/// 전환 액션을 노출해 구체 타입 의존을 끊는다.
@Observable
final class AppFlowViewModel {

    // MARK: - Property

    private(set) var state: AppFlowState = .bootstrap

    /// 하위 Feature가 구체 타입 없이 화면 전환을 요청할 수 있도록 노출하는 환경 값.
    var appFlow: AppFlow {
        AppFlow(
            showLogin: { [weak self] in self?.showLogin() },
            showMain: { [weak self] in self?.showMain() },
            logout: { [weak self] in self?.logout() }
        )
    }

    // MARK: - Init

    init() {}

    // MARK: - Function

    func showBootstrap() {
        transition(to: .bootstrap)
    }

    func showLogin() {
        transition(to: .login)
    }

    func showMain() {
        transition(to: .main)
    }

    /// 세션 만료 등으로 로그아웃 처리 후 로그인 화면으로 되돌린다.
    func logout() {
        transition(to: .login)
    }

    // MARK: - Private Function

    private func transition(to newState: AppFlowState) {
        guard newState != state else { return }
        state = newState
    }
}
