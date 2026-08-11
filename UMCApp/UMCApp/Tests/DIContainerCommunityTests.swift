//
//  DIContainerCommunityTests.swift
//  UMCAppTests
//

import CommunityData
import CommunityDomain
import CoreDI
import CoreNetwork
import Foundation
import Testing

@testable import UMCApp

// MARK: - Helpers

/// Community 의존성이 등록된 컨테이너를 만든다.
///
/// `DIContainer.configured(modelContext:)` 는 SwiftData 컨테이너를 요구하므로, Community 조립이
/// 실제로 소비하는 공유 인프라(`TokenStore`·`MoyaNetworkAdapter`)만 운영과 같은 방식으로 먼저
/// 등록한다. 등록·해석 시점에는 네트워크 왕복도 소켓 연결도 없어 실제 구현을 그대로 쓴다.
private func makeContainer(
    onTokenStoreFactoryCall: @escaping () -> Void = {}
) throws -> DIContainer {
    // 요청을 보내지 않는 테스트용 base URL.
    let baseURL = try #require(URL(string: "https://test.invalid"))
    let container = DIContainer()
    container.register(TokenStore.self) {
        onTokenStoreFactoryCall()
        return KeychainTokenStore()
    }
    container.register(MoyaNetworkAdapter.self) {
        MoyaNetworkAdapter(
            networkClient: AuthSystemFactory.makeNetworkClient(baseURL: baseURL),
            baseURL: baseURL
        )
    }
    container.registerCommunityDependencies()
    return container
}

// MARK: - Tests

@Suite("DIContainer+Community — Community 의존성 조립")
struct DIContainerCommunityTests {

    // MARK: - Resolution

    @Test("스레드 UseCase 가 등록되어 해석된다")
    func resolvesThreadUseCases() throws {
        let container = try makeContainer()

        #expect(container.resolveIfRegistered(CommunityThreadListUseCaseProtocol.self) != nil)
        #expect(container.resolveIfRegistered(CommunityThreadRoomUseCaseProtocol.self) != nil)
    }

    @Test("Repository 가 등록되어 해석된다")
    func resolvesThreadRepository() throws {
        let container = try makeContainer()

        #expect(container.resolveIfRegistered(CommunityThreadRepositoryProtocol.self) != nil)
    }

    // MARK: - 프로세스 단일 인스턴스

    /// 구독 destination 이 유저별이라 실시간 클라이언트는 프로세스에 하나여야 한다.
    ///
    /// 팩토리가 매번 새 인스턴스를 만들면 두 번째 클라이언트의 `StompConnection.events()` 가
    /// 단일 소비자용인 앞 스트림을 조용히 `finish()` 해, 에러도 로그도 없이 이벤트만 끊긴다.
    /// 실패 증상이 보이지 않는 종류라 등록 단계에서 잠근다.
    @Test("실시간 클라이언트는 매번 같은 인스턴스로 해석된다")
    func realtimeClientResolvesToSameInstance() throws {
        let container = try makeContainer()

        let first = try #require(
            container.resolve(CommunityThreadRealtimeProtocol.self)
                as? CommunityThreadRealtimeClient
        )
        let second = try #require(
            container.resolve(CommunityThreadRealtimeProtocol.self)
                as? CommunityThreadRealtimeClient
        )

        #expect(first === second)
    }

    /// 실시간 클라이언트가 하나여도 그 아래 연결이 두 벌이면 같은 단일 소비자 계약이 깨진다.
    @Test("STOMP 연결은 매번 같은 인스턴스로 해석된다")
    func stompConnectionResolvesToSameInstance() throws {
        let container = try makeContainer()

        let first = container.resolve(StompConnection.self)
        let second = container.resolve(StompConnection.self)

        #expect(first === second)
    }

    // MARK: - 공유 인프라 재사용

    /// Community 등록이 `TokenStore` 를 자체 등록하면 미리 등록된 팩토리가 밀려나 호출 횟수가
    /// 0 이 된다. 1 이어야 운영 부트스트랩이 등록한 canonical 을 그대로 재사용했다는 뜻이다.
    @Test("STOMP 연결은 이미 등록된 TokenStore 를 재사용한다")
    func reusesRegisteredTokenStore() throws {
        var tokenStoreFactoryCallCount = 0
        let container = try makeContainer { tokenStoreFactoryCallCount += 1 }

        _ = container.resolve(StompConnection.self)

        #expect(tokenStoreFactoryCallCount == 1)
    }
}
