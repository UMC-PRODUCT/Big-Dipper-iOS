//
//  AuthSystemFactoryTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import Testing
@testable import CoreNetwork

@Suite("AuthSystemFactory")
struct AuthSystemFactoryTests {

    @Test("makeNetworkClient는 baseURL로 NetworkClient 인스턴스를 만든다")
    func makesProductionClient() async {
        let baseURL = URL(string: "https://api.umc.test")!
        let client = AuthSystemFactory.makeNetworkClient(baseURL: baseURL)

        // 토큰 미설정 상태 → 로그인 안 된 상태
        let loggedIn = await client.isLoggedIn()
        #expect(!loggedIn)
    }

    @Test("makeNetworkClient는 외부에서 주입한 tokenStore를 사용한다")
    func makesProductionClientWithInjectedStore() async {
        let baseURL = URL(string: "https://api.umc.test")!
        let injected = MockTokenStore(accessToken: "INJECTED", refreshToken: "R")

        let client = AuthSystemFactory.makeNetworkClient(
            baseURL: baseURL,
            tokenStore: injected
        )

        let loggedIn = await client.isLoggedIn()
        #expect(loggedIn, "주입한 store에 토큰이 있으므로 로그인 상태여야 한다")
    }

    @Test("makeTestNetworkClient는 주입된 의존성으로 NetworkClient를 조립한다")
    func makesTestClient() async {
        let store = MockTokenStore(accessToken: "TEST", refreshToken: "R")
        let refresh = MockTokenRefreshService(
            behavior: .success(TokenPair(accessToken: "X", refreshToken: "Y"))
        )

        let client = AuthSystemFactory.makeTestNetworkClient(
            tokenStore: store,
            refreshService: refresh
        )

        let loggedIn = await client.isLoggedIn()
        #expect(loggedIn)
    }
}
