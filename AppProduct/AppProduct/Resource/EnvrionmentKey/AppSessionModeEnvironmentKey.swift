//
//  AppSessionModeEnvironmentKey.swift
//  AppProduct
//

import SwiftUI

// MARK: - AppSessionMode

/// 앱 세션의 인증 모드를 나타내는 열거형
///
/// 하위 뷰에서 `@Environment(\.appSessionMode)`로 접근하여
/// 인증 세션 종류에 따라 동작을 분기할 수 있습니다.
enum AppSessionMode: Equatable {
    /// 정상 인증 세션
    case authenticated
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
