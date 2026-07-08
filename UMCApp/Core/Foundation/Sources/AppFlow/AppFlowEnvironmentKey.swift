//
//  AppFlowEnvironmentKey.swift
//  UMCFoundation
//

import SwiftUI

/// `\.appFlow` — 앱 전역 화면 전환 액션을 SwiftUI Environment로 주입하는 키.
///
/// 앱 루트(`AppRootView`)가 실제 상태머신을 소유하고, 하위 Feature는 구체 타입을 몰라도
/// 이 클로저 집합만으로 전환을 요청할 수 있다.
///
/// ### View에서 사용
/// ```swift
/// struct LoginView: View {
///     @Environment(\.appFlow) private var appFlow
///
///     var body: some View {
///         Button("로그인 완료") { appFlow.showMain() }
///     }
/// }
/// ```
///
/// - Note: `signUp` / `pendingApproval` 등 후속 상태 전환 액션은 해당 상태가 도입되는
///   이슈에서 이 구조체에 확장될 예정이다.
/// - Warning: 기본값은 `noop` — 루트에서 주입 없이 호출해도 크래시 없이 무시된다.
public struct AppFlow {

    // MARK: - Property

    public let showLogin: () -> Void
    public let showMain: () -> Void
    public let logout: () -> Void

    // MARK: - Init

    public init(
        showLogin: @escaping () -> Void,
        showMain: @escaping () -> Void,
        logout: @escaping () -> Void
    ) {
        self.showLogin = showLogin
        self.showMain = showMain
        self.logout = logout
    }

    public static let noop = AppFlow(showLogin: {}, showMain: {}, logout: {})
}

public struct AppFlowEnvironmentKey: EnvironmentKey {
    public static let defaultValue: AppFlow = .noop
}

extension EnvironmentValues {
    public var appFlow: AppFlow {
        get { self[AppFlowEnvironmentKey.self] }
        set { self[AppFlowEnvironmentKey.self] = newValue }
    }
}
