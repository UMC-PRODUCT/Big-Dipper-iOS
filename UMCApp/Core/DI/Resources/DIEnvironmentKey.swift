//
//  DIEnvironmentKey.swift
//  CoreDI
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI


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
public struct DIEnvironmentKey: EnvironmentKey {
    public static let defaultValue: DIContainer = .init()
}

extension EnvironmentValues {
    public var di: DIContainer {
        get { self[DIEnvironmentKey.self] }
        set { self[DIEnvironmentKey.self] = newValue }
    }
}
