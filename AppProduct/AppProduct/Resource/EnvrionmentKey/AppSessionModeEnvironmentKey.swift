//
//  AppSessionModeEnvironmentKey.swift
//  AppProduct
//

import SwiftUI

// MARK: - AppSessionMode

/// 앱 세션의 인증 모드를 나타내는 열거형
///
/// 하위 뷰에서 `@Environment(\.appSessionMode)`로 접근하여
/// 게스트 세션 여부에 따라 쓰기 액션을 제어할 수 있습니다.
enum AppSessionMode: Equatable {
    /// 정상 OAuth 인증 세션
    case authenticated
    /// 게스트 세션 (네트워크 미사용, Mock 데이터)
    case guest

    var isGuest: Bool { self == .guest }
}

// MARK: - EnvironmentKey

struct AppSessionModeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppSessionMode = .authenticated
}

extension EnvironmentValues {
    var appSessionMode: AppSessionMode {
        get { self[AppSessionModeEnvironmentKey.self] }
        set { self[AppSessionModeEnvironmentKey.self] = newValue }
    }
}
