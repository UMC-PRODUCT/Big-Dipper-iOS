//
//  DIEnvironmentKey.swift
//  CoreDI
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI

/// `\.di` — DIContainer를 SwiftUI Environment로 주입하는 키.
///
/// 앱 루트에서 `.environment(\.di, DIContainer.configured(...))`로 주입하고,
/// 피처는 `import CoreDI` 후 `@Environment(\.di)`로 읽는다.
///
/// ### View에서 사용
/// ```swift
/// struct LoginView: View {
///     @Environment(\.di) private var container
///
///     var body: some View {
///         Button("로그인") {
///             let useCase = container.resolve(LoginUseCaseProtocol.self)
///             useCase.execute()
///         }
///     }
/// }
/// ```
/// - Warning: 기본값은 빈 컨테이너 — 루트에서 주입 없이 `resolve` 호출 시
///   "No Factory registered" `fatalError`로 주입 누락이 드러난다.
public struct DIEnvironmentKey: EnvironmentKey {
    public static let defaultValue: DIContainer = DIContainer()
}

extension EnvironmentValues {
    public var di: DIContainer {
        get { self[DIEnvironmentKey.self] }
        set { self[DIEnvironmentKey.self] = newValue }
    }
}
