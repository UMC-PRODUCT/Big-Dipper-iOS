//
//  DIContainer.swift
//  CoreDI
//
//  Created by 이예지 on 5/26/26.
//

import Foundation
import SwiftData
import CoreNetwork

// MARK: - DIContainer 사용 예시
/// DIContainer는 의존성 주입(Dependency Injection)을 관리하는 컨테이너입니다.
/// 프로토콜과 구현체를 등록하고, 필요한 곳에서 resolve하여 사용합니다.
///
/// ## 기본 사용법
///
/// ### 1. 컨테이너 생성 및 의존성 등록
/// ```swift
/// let container = DIContainer()
///
/// // 프로토콜 타입으로 등록 (권장)
/// container.register(UserRepositoryProtocol.self) {
///     UserRepository()
/// }
///
/// // UseCase 등록 (Repository 의존성 주입)
/// container.register(LoginUseCaseProtocol.self) {
///     LoginUseCase(repository: container.resolve(UserRepositoryProtocol.self))
/// }
/// ```
///
/// ### 2. 등록된 의존성 사용
/// ```swift
/// // resolve로 인스턴스 가져오기 (싱글톤처럼 캐싱됨)
/// let userRepository = container.resolve(UserRepositoryProtocol.self)
/// let loginUseCase = container.resolve(LoginUseCaseProtocol.self)
/// ```
///
/// ### 3. 캐시 관리
/// ```swift
/// // 특정 타입의 캐시만 초기화
/// container.resetCache(for: UserRepositoryProtocol.self)
///
/// // 모든 캐시 초기화 (로그아웃 시 활용)
/// container.resetCache()
/// ```
///
/// ## SwiftUI에서 활용
///
/// ### App 진입점에서 Environment로 주입
/// ```swift
/// @main
/// struct MyApp: App {
///     @State private var container = DIContainer()
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environment(container)
///         }
///     }
/// }
/// ```
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

@Observable
public final class DIContainer {
    
    public init() {}

    // MARK: - Storage
    /// @ObservationIgnored: resolve() 시 cachedInstances 쓰기가 @Observable 변경 알림을 발생시켜
    /// NavigationStack push 중 연쇄 뷰 무효화 → "tried to update multiple times per frame" 경고를 유발하므로
    /// 관찰 대상에서 제외합니다.
    @ObservationIgnored
    private var factories: [ObjectIdentifier: Any] = [:]
    @ObservationIgnored
    private var cachedInstances: [ObjectIdentifier: Any] = [:]
    
    // MARK: - Registration

    /// 프로토콜 타입과 팩토리 클로저를 등록합니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 프로토콜/타입 (예: `UserRepositoryProtocol.self`)
    ///   - factory: 인스턴스를 생성하는 클로저
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = ObjectIdentifier(type)
        factories[key] = factory
    }
    
    // MARK: - Resolution

    /// 등록된 의존성을 조회합니다 (캐싱됨).
    ///
    /// 최초 호출 시 팩토리 클로저로 인스턴스를 생성하고 캐시합니다.
    /// 이후 호출부터는 캐시된 인스턴스를 반환합니다 (싱글톤 동작).
    ///
    /// - Parameter type: 조회할 프로토콜/타입
    /// - Returns: 등록된 타입의 인스턴스
    /// - Warning: 미등록 타입 조회 시 `fatalError` 발생. 안전한 조회는 `resolveIfRegistered` 사용.
    public func resolve<T>(_ type: T.Type) -> T {
        let key = ObjectIdentifier(type)
        if let cached = cachedInstances[key] as? T {
            return cached
        }
        guard let factory = factories[key] as? () -> T else {
            fatalError("DIContainer Error: No Factory registered for type '\(T.self)'.")
        }
        let instance = factory()
        cachedInstances[key] = instance
        return instance
    }

    /// 등록 여부를 확인하며 의존성을 안전하게 조회합니다.
    ///
    /// 캐시 미스면 `resolve`와 똑같이 **팩토리를 실행해 새 인스턴스를 만들고 캐시합니다.**
    /// 미등록일 때만 `fatalError` 대신 nil을 돌려주는 점이 `resolve`와의 유일한 차이입니다.
    ///
    /// - Returns: 등록된 경우 인스턴스, 미등록 시 nil
    public func resolveIfRegistered<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)
        if let cached = cachedInstances[key] as? T {
            return cached
        }
        guard let factory = factories[key] as? () -> T else {
            return nil
        }
        let instance = factory()
        cachedInstances[key] = instance
        return instance
    }

    /// 이미 생성되어 캐시된 인스턴스만 조회합니다.
    ///
    /// `resolve`/`resolveIfRegistered`와 달리 **캐시 미스 시 팩토리를 실행하지도, 캐시를 채우지도
    /// 않습니다.** 살아 있는 인스턴스만 정리하고 싶은 경우 — 예: `resetCache()`로 참조를 버리기
    /// 전에 종료 처리(`stop()`)가 필요한 연결 — 에 사용합니다. 그 자리에
    /// `resolveIfRegistered`를 쓰면 정리하려던 순간에 인스턴스를 새로 만들어 캐시에 남깁니다.
    ///
    /// - Returns: 캐시된 인스턴스, 아직 생성되지 않았으면 nil
    public func resolveIfCached<T>(_ type: T.Type) -> T? {
        cachedInstances[ObjectIdentifier(type)] as? T
    }

    // MARK: - Cache Management

    /// 모든 캐시된 인스턴스를 초기화합니다.
    ///
    /// - Note: 로그아웃 시 호출하여 이전 사용자 상태를 제거합니다.
    public func resetCache() {
        cachedInstances.removeAll()
    }
    
    /// 특정 타입의 캐시된 인스턴스만 초기화합니다.
    ///
    /// - Parameter type: 캐시를 제거할 타입
    public func resetCache<T>(for type: T.Type) {
        let key = ObjectIdentifier(type)
        cachedInstances.removeValue(forKey: key)
    }
}

// MARK: - 앱 의존성 구성
extension DIContainer {
    
    /// 앱에서 사용하는 모든 의존성을 등록한 DIContainer를 반환합니다.
    /// - Parameter modelContext: SwiftData ModelContext (CloudKit 저장소용)
    public static func configured(
        modelContext: ModelContext
    ) -> DIContainer {
        let container = DIContainer()

        // MARK: - SwiftData
        container.register(ModelContext.self) {
            modelContext
        }

        // MARK: - Token Store (NetworkClient보다 먼저 등록)
        // 팩토리 밖에서 한 번만 만들어 캡처한다. 팩토리 안에서 만들면 로그아웃의
        // `resetCache()` 뒤 다음 resolve가 **새** 인스턴스를 만들어, 옛 인스턴스를 붙잡은
        // 쪽(워치 요청 핸들러·STOMP 펌프)은 `clear()`로 비워진 인메모리 캐시를 그대로 든 채
        // 굳는다 — 재로그인해도 토큰을 영영 못 본다. Keychain이 정본이라 인스턴스를 나눠 쓸
        // 이유가 없다.
        let tokenStore = KeychainTokenStore()
        container.register(TokenStore.self) {
            tokenStore
        }

        // MARK: - Network Infrastructure
        container.register(NetworkClient.self) {
            AuthSystemFactory.makeNetworkClient(
                baseURL: NetworkConfig.baseURL,
                tokenStore: container.resolve(TokenStore.self)
            )
        }

        // MARK: - Moya Network Adapter
        container.register(MoyaNetworkAdapter.self) {
            MoyaNetworkAdapter(
                networkClient: container.resolve(NetworkClient.self),
                baseURL: NetworkConfig.baseURL
            )
        }
        return container
    }

}
