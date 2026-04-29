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
    /// ID/PW 회원가입 화면으로 전환합니다 (파라미터 없음 — 폼이 모든 입력을 받음).
    let showSignUpByIdPw: () -> Void
    let showPendingApproval: () -> Void
    let logout: () -> Void

    static let noop = AppFlow(
        showLogin: {},
        showMain: {},
        showSignUp: { _, _, _, _ in },
        showSignUpByIdPw: {},
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
