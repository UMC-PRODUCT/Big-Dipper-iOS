//
//  DIContainer+Community.swift
//  UMCApp
//

import CommunityData
import CommunityDomain
import CoreDI
import CoreNetwork

extension DIContainer {

    /// Community 스레드 계층의 Presentation → Domain → Data 조립을 등록한다.
    ///
    /// `StompConnection` 과 ``CommunityData/CommunityThreadRealtimeClient`` 는 프로세스에 하나여야
    /// 한다. 구독 destination 이 유저별이라 `StompConnection.events()` 가 단일 소비자 계약이고,
    /// 두 번째 호출이 앞 스트림을 조용히 `finish()` 하기 때문이다. `resolve` 가 타입 키로 첫
    /// 생성분을 캐싱하므로 이 등록만으로 앱 생명주기 싱글턴이 된다
    /// (회귀 가드: `DIContainerCommunityTests`).
    ///
    /// - Important: 등록 시점에 `start()` 를 부르지 않는다. 연결은 스레드 화면이 열릴 때 시작한다.
    /// - Note: `MoyaNetworkAdapter`/`TokenStore` 는 ``DIContainer/configured(modelContext:)`` 가
    ///   등록한 공유 인프라이므로 재등록하지 않고 `resolve` 로만 재사용한다.
    func registerCommunityDependencies() {
        registerCommunityRealtime()
        registerCommunityRepositories()
        registerCommunityUseCases()
    }

    // MARK: - Realtime

    private func registerCommunityRealtime() {
        register(StompConnection.self) {
            StompConnection(
                url: StompConnection.webSocketURL(base: NetworkConfig.baseURL),
                tokenStore: self.resolve(TokenStore.self)
            )
        }
        register(CommunityThreadRealtimeProtocol.self) {
            CommunityThreadRealtimeClient(connection: self.resolve(StompConnection.self))
        }
    }

    // MARK: - Repository

    private func registerCommunityRepositories() {
        register(CommunityThreadRepositoryProtocol.self) {
            CommunityThreadRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
    }

    // MARK: - UseCase

    private func registerCommunityUseCases() {
        register(CommunityThreadListUseCaseProtocol.self) {
            CommunityThreadListUseCase(
                repository: self.resolve(CommunityThreadRepositoryProtocol.self)
            )
        }
        register(CommunityThreadCreateUseCaseProtocol.self) {
            CommunityThreadCreateUseCase(
                repository: self.resolve(CommunityThreadRepositoryProtocol.self)
            )
        }
        register(CommunityThreadRoomUseCaseProtocol.self) {
            CommunityThreadRoomUseCase(
                repository: self.resolve(CommunityThreadRepositoryProtocol.self),
                realtime: self.resolve(CommunityThreadRealtimeProtocol.self)
            )
        }
    }
}
