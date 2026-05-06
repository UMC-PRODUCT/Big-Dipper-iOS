//
//  DIContainer.swift
//  DIContainer
//
//  Created by euijjang97 on 12/29/25.
//

import Foundation
import SwiftData

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
final class DIContainer {
    
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
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
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
    func resolve<T>(_ type: T.Type) -> T {
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
    /// - Returns: 등록된 경우 인스턴스, 미등록 시 nil
    func resolveIfRegistered<T>(_ type: T.Type) -> T? {
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
    
    // MARK: - Cache Management

    /// 모든 캐시된 인스턴스를 초기화합니다.
    ///
    /// - Note: 로그아웃 시 호출하여 이전 사용자 상태를 제거합니다.
    func resetCache() {
        cachedInstances.removeAll()
    }
    
    /// 특정 타입의 캐시된 인스턴스만 초기화합니다.
    ///
    /// - Parameter type: 캐시를 제거할 타입
    func resetCache<T>(for type: T.Type) {
        let key = ObjectIdentifier(type)
        cachedInstances.removeValue(forKey: key)
    }
}

// MARK: - 앱 의존성 구성
extension DIContainer {
    
    /// 앱에서 사용하는 모든 의존성을 등록한 DIContainer를 반환합니다.
    /// - Parameter modelContext: SwiftData ModelContext (CloudKit 저장소용)
    static func configured(
        modelContext: ModelContext
    ) -> DIContainer {
        let container = DIContainer()
        container.register(PathStore.self) { PathStore() }
        container.register(NavigationRouter.self) { NavigationRouter() }
        container.register(UserSessionManager.self) { UserSessionManager() }
        
        // MARK: - Token Store (NetworkClient보다 먼저 등록)
        container.register(TokenStore.self) {
            KeychainTokenStore()
        }

        // MARK: - Network Infrastructure
        container.register(NetworkClient.self) {
            AuthSystemFactory.makeNetworkClient(
                baseURL: URL(string: Config.baseURL)!,
                tokenStore: container.resolve(TokenStore.self)
            )
        }
        
        container.register(MoyaNetworkAdapter.self) {
            MoyaNetworkAdapter(
                networkClient: container.resolve(NetworkClient.self),
                baseURL: URL(string: Config.baseURL)!
            )
        }
        
        // MARK: - Storage Infrastructure
        container.register(StorageRepositoryProtocol.self) {
            StorageRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        
        // MARK: - Common Authorization
        container.register(AuthorizationRepositoryProtocol.self) {
            AuthorizationRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(AuthorizationUseCaseProtocol.self) {
            AuthorizationUseCase(
                repository: container.resolve(AuthorizationRepositoryProtocol.self)
            )
        }
        
        // MARK: - Token Store
        container.register(TokenStore.self) {
            KeychainTokenStore()
        }
        
        // MARK: - Cross-Feature Repository
        container.register(ScheduleClassifierRepository.self) {
            ScheduleClassifierRepositoryImpl()
        }
        
        // MARK: - Activity Feature
        container.register(ActivityRepositoryProviding.self) {
            ActivityRepositoryProvider.real(
                adapter: container.resolve(MoyaNetworkAdapter.self),
                homeRepository: container.resolve(HomeRepositoryProtocol.self)
            )
        }
        container.register(ActivityUseCaseProviding.self) {
            ActivityUseCaseProvider(
                repositoryProvider: container.resolve(
                    ActivityRepositoryProviding.self
                ),
                classifierRepository: container.resolve(
                    ScheduleClassifierRepository.self
                )
            )
        }
        
        // MARK: - Auth Feature
        container.register(AuthRepositoryProviding.self) {
            AuthRepositoryProvider.real(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(AuthUseCaseProviding.self) {
            AuthUseCaseProvider(
                repositoryProvider: container.resolve(
                    AuthRepositoryProviding.self
                ),
                tokenStore: container.resolve(TokenStore.self)
            )
        }
        
        // MARK: - Home Feature
        container.register(HomeRepositoryProtocol.self) {
            HomeRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(ScheduleRepositoryProtocol.self) {
            ScheduleRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(ScheduleCapabilitiesRepositoryProtocol.self) {
            ScheduleCapabilitiesRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(FetchScheduleCapabilitiesUseCaseProtocol.self) {
            FetchScheduleCapabilitiesUseCase(
                repository: container.resolve(ScheduleCapabilitiesRepositoryProtocol.self)
            )
        }
        container.register(ChallengerGenRepositoryProtocol.self) {
            ChallengerGenRepository(modelContext: modelContext)
        }
        container.register(ChallengerSearchRepositoryProtocol.self) {
            ChallengerSearchRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(HomeUseCaseProviding.self) {
            HomeUseCaseProvider(
                homeRepository: container.resolve(
                    HomeRepositoryProtocol.self
                ),
                scheduleRepository: container.resolve(
                    ScheduleRepositoryProtocol.self
                ),
                classifierRepository: container.resolve(
                    ScheduleClassifierRepository.self
                ),
                challengerSearchRepository: container.resolve(
                    ChallengerSearchRepositoryProtocol.self
                )
            )
        }
        
        // MARK: - Notice Feature
        container.register(NoticeRepositoryProtocol.self) {
            NoticeRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(NoticeReadRepositoryProtocol.self) {
            NoticeReadRepository(modelContext: modelContext)
        }
        container.register(NoticeUseCaseProtocol.self) {
            NoticeUseCase(
                repository: container.resolve(NoticeRepositoryProtocol.self),
                storageRepository: container.resolve(StorageRepositoryProtocol.self)
            )
        }
        container.register(NoticeEditorTargetRepositoryProtocol.self) {
            NoticeEditorTargetRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(NoticeEditorTargetUseCaseProtocol.self) {
            NoticeEditorTargetUseCase(
                repository: container.resolve(NoticeEditorTargetRepositoryProtocol.self)
            )
        }
        
        // MARK: - MyPage Feature
        container.register(MyPageRepositoryProtocol.self) {
            MyPageRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self),
                storageRepository: container.resolve(StorageRepositoryProtocol.self)
            )
        }
        /// 프로필 조회/수정 UseCase를 제공하는 Provider
        container.register(MyPageUseCaseProviding.self) {
            MyPageUseCaseProvider(
                repository: container.resolve(MyPageRepositoryProtocol.self)
            )
        }
        
        // MARK: - Community Feature
        container.register(TMapGeocodingRepositoryProtocol.self) {
            TMapGeocodingRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(CommunityRepositoryProtocol.self) {
            CommunityRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(CommunityPostRepositoryProtocol.self) {
            CommunityPostRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(CommunityDetailRepositoryProtocol.self) {
            CommunityDetailRepository(
                adapter: container.resolve(MoyaNetworkAdapter.self)
            )
        }
        container.register(CommunityUseCaseProviding.self) {
            CommunityUseCaseProvider(
                communityRepository: container.resolve(
                    CommunityRepositoryProtocol.self
                ),
                communityPostRepository: container.resolve(
                    CommunityPostRepositoryProtocol.self
                ),
                communityDetailRepository: container.resolve(
                    CommunityDetailRepositoryProtocol.self
                )
            )
        }

        return container
    }

}
