//
//  Resolver.swift
//  UMCFoundation
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

// MARK: - Resolver

/// DI 컨테이너의 조회(resolve) 능력만 노출하는 추상.
///
/// 피처 레이어는 이 프로토콜에만 의존하고, 구체 `DIContainer`(CoreDI)는 모른다.
/// `DIContainer`가 CoreDI에서 이 프로토콜을 채택한다.
///
/// ```swift
/// @Environment(\.di) private var di            // any Resolver
/// let useCase = di.resolve(LoginUseCaseProtocol.self)
/// ```
///
/// ### ViewModel — 생성자 주입
///
/// `ViewModel` 은 `@Environment` 를 쓸 수 없으므로 **생성자로** `any Resolver` 를 받는다.
///
/// ```swift
/// import UMCFoundation
/// import NoticeDomain
/// // import CoreDI  ← 불필요
///
/// @Observable
/// public final class NoticeViewModel {
///
///     // MARK: - Dependency
///     private let container: any Resolver
///
///     // MARK: - Lifecycle
///     public init(container: any Resolver, errorHandler: ErrorHandler) {
///         self.container = container
///         self.errorHandler = errorHandler
///         self.noticeUseCase = container.resolve(NoticeUseCaseProtocol.self)
///     }
/// }
/// ```
///
/// ### View — 루트에서 `\.di` 를 한 번 읽어 전달
///
/// 컨테이너의 소스는 `\.di` 다. **루트 View 가 한 번 읽어** 생성자 체인으로 흘려보낸다.
///
/// ```swift
/// import SwiftUI
/// import UMCFoundation
/// import NoticePresentation
///
/// struct ContentView: View {
///     @Environment(\.di) private var di        // any Resolver
///     private let errorHandler = ErrorHandler()
///
///     var body: some View {
///         NoticeView(container: di, errorHandler: errorHandler)
///     }
/// }
/// ```
public protocol Resolver {

    
    /// 등록된 의존성을 조회한다.
    /// - Parameter type: 조회할 프로토콜/타입 (예: `LoginUseCaseProtocol.self`)
    /// - Returns: 등록된 타입의 인스턴스
    /// - Warning: 미등록·미주입 시 `fatalError`.
    func resolve<T>(_ type: T.Type) -> T
}

// MARK: - UnregisteredResolver

/// `\.di`의 기본값 백킹 — 앱 루트에서 컨테이너가 주입되기 전 상태.
///
/// Foundation은 `DIContainer`(CoreDI)를 생성할 수 없어, 기본값 자리에 둘
/// 로컬 conformer가 필요하다. 실제 앱은 루트에서
/// `.environment(\.di, DIContainer.configured(...))`로 교체하므로,
/// 이 타입의 `resolve`가 불렸다는 건 곧 주입 누락을 의미한다.
public struct UnregisteredResolver: Resolver {
    public func resolve<T>(_ type: T.Type) -> T {
        fatalError(
            "\\.di has no injected container. Inject "
            + "DIContainer.configured(...) at the app root before resolving \(T.self)."
        )
    }
}
