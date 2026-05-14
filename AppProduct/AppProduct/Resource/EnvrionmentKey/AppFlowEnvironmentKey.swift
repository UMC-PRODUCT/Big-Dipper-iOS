//
//  AppFlowEnvironmentKey.swift
//  AppProduct
//

import SwiftUI

/// 앱 전역 화면 전환/세션 액션 집합
struct AppFlow {
    let showLogin: () -> Void
    let showMain: () -> Void
    let showSignUp: (
        String,
        String?,
        String?,
        PostRegisterLoginContext?
    ) -> Void
    let showPendingApproval: () -> Void
    let logout: () -> Void

    static let noop = AppFlow(
        showLogin: {},
        showMain: {},
        showSignUp: { _, _, _, _ in },
        showPendingApproval: {},
        logout: {}
    )
}

struct AppFlowEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppFlow = .noop
}

extension EnvironmentValues {
    var appFlow: AppFlow {
        get { self[AppFlowEnvironmentKey.self] }
        set { self[AppFlowEnvironmentKey.self] = newValue }
    }
}
