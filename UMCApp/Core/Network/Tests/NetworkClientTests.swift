//
//  NetworkClientTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import CoreNetwork

@Suite("NetworkClient", .serialized)
@MainActor
struct NetworkClientTests {

    // MARK: - Fixtures

    private let testURL = URL(string: "https://api.umc.test/api/v1/me")!

    private func makeClient(
        store: MockTokenStore,
        refresh: MockTokenRefreshService,
        maxRetryCount: Int = 1
    ) -> NetworkClient {
        StubURLProtocol.reset()
        let session = makeStubSession()
        return NetworkClient(
            session: session,
            tokenStore: store,
            refreshService: refresh,
            authPolicy: DefaultAuthenticationPolicy(),
            maxRetryCount: maxRetryCount
        )
    }

    // MARK: - isLoggedIn / logout

    @Test("토큰이 있으면 isLoggedIn이 true다")
    func isLoggedInTrue() async {
        let store = MockTokenStore(accessToken: "A", refreshToken: "R")
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = makeClient(store: store, refresh: refresh)

        let loggedIn = await client.isLoggedIn()
        #expect(loggedIn)
    }

    @Test("토큰이 없으면 isLoggedIn이 false다")
    func isLoggedInFalse() async {
        let store = MockTokenStore()
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = makeClient(store: store, refresh: refresh)

        let loggedIn = await client.isLoggedIn()
        #expect(!loggedIn)
    }

    @Test("logout 호출 시 tokenStore.clear()가 1회 호출된다")
    func logoutClearsTokens() async throws {
        let store = MockTokenStore(accessToken: "A", refreshToken: "R")
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = makeClient(store: store, refresh: refresh)

        try await client.logout()

        let clearCount = await store.clearCallCount
        let access = await store.accessToken
        #expect(clearCount == 1)
        #expect(access == nil)
    }

    // MARK: - request: Authorization 주입

    @Test("인증 정책이 true이고 액세스 토큰이 있으면 Authorization 헤더가 주입된다")
    func injectsAuthorizationHeader() async throws {
        let store = MockTokenStore(accessToken: "ACCESS123", refreshToken: "R")
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data("{}".utf8), 200, nil) }

        let request = URLRequest(url: testURL)
        _ = try await client.request(request)

        let captured = try #require(StubURLProtocol.capturedRequests.first)
        #expect(captured.value(forHTTPHeaderField: "Authorization") == "Bearer ACCESS123")
    }

    // MARK: - 401 → refresh → retry

    @Test("401 응답 시 refresh 후 새 액세스 토큰으로 재시도하고 200을 반환한다")
    func refreshOn401AndRetry() async throws {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(
            behavior: .success(TokenPair(accessToken: "NEW", refreshToken: "NEW_R"))
        )
        let client = makeClient(store: store, refresh: refresh)

        // 1번째 호출: 401, 2번째 호출(refresh 후): 200
        let callCount = LockedCounter()
        StubURLProtocol.handler = { _ in
            let n = callCount.increment()
            if n == 1 {
                return (Data(), 401, nil)
            } else {
                return (Data("{\"ok\":true}".utf8), 200, nil)
            }
        }

        let request = URLRequest(url: testURL)
        let (data, response) = try await client.request(request)

        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "{\"ok\":true}")

        let refreshCalls = await refresh.callCount
        #expect(refreshCalls == 1)

        let stored = await store.accessToken
        #expect(stored == "NEW")

        // 두 번째 요청에서 새 토큰이 헤더에 들어가야 한다
        let secondRequest = StubURLProtocol.capturedRequests[1]
        #expect(secondRequest.value(forHTTPHeaderField: "Authorization") == "Bearer NEW")
    }

    @Test("401이 재시도 후에도 다시 발생하면 maxRetryExceeded를 throw한다")
    func maxRetryExceededAfterRetry() async {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(
            behavior: .success(TokenPair(accessToken: "NEW", refreshToken: "NEW_R"))
        )
        let client = makeClient(store: store, refresh: refresh, maxRetryCount: 1)

        StubURLProtocol.handler = { _ in (Data(), 401, nil) }

        await #expect(throws: NetworkError.maxRetryExceeded) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }
    }

    @Test("refresh가 실패하면 NetworkError.tokenRefreshFailed를 throw한다")
    func refreshFailureWraps() async {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(behavior: .failure(.invalidRefreshToken))
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data(), 401, nil) }

        await #expect(throws: NetworkError.self) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }
    }

    @Test("갱신 중 네트워크가 끊기면 noNetwork를 throw하고 저장된 토큰은 유지한다")
    func transportFailureKeepsSession() async {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(
            behavior: .transportFailure(URLError(.notConnectedToInternet))
        )
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data(), 401, nil) }

        await #expect(throws: NetworkError.noNetwork) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }

        let clearCount = await store.clearCallCount
        let refreshToken = await store.refreshToken
        #expect(clearCount == 0)
        #expect(refreshToken == "REFRESH")
    }

    @Test("갱신 요청이 타임아웃되면 timeout을 throw한다")
    func transportTimeoutIsNotSessionExpiry() async {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(behavior: .transportFailure(URLError(.timedOut)))
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data(), 401, nil) }

        await #expect(throws: NetworkError.timeout) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }
    }

    @Test("서버가 리프레시 토큰을 거부(401)하면 tokenRefreshFailed를 throw한다")
    func serverRejectionBecomesTokenRefreshFailed() async {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(behavior: .rejectedByServer(statusCode: 401))
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data(), 401, nil) }

        await #expect(
            throws: NetworkError.tokenRefreshFailed(reason: "서버 에러 (status: 401)")
        ) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }
    }

    @Test("갱신 API가 5xx면 세션 만료가 아니라 requestFailed로 전파된다")
    func serverOutageIsNotSessionExpiry() async {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(behavior: .rejectedByServer(statusCode: 503))
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data(), 401, nil) }

        await #expect(throws: NetworkError.requestFailed(statusCode: 503, data: nil)) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }
    }

    @Test("리프레시 토큰이 없으면 NetworkError.noRefreshToken을 throw한다")
    func noRefreshTokenError() async {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: nil)
        let refresh = MockTokenRefreshService(
            behavior: .success(TokenPair(accessToken: "NEW", refreshToken: "NEW_R"))
        )
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data(), 401, nil) }

        await #expect(throws: NetworkError.self) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }
    }

    // MARK: - Single-flight refresh

    @Test("동시 다발적 401에서도 토큰 갱신은 단 1회만 실행된다 (single-flight)")
    func singleFlightRefresh() async throws {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let refresh = MockTokenRefreshService(
            behavior: .delayedSuccess(
                TokenPair(accessToken: "NEW", refreshToken: "NEW_R"),
                nanoseconds: 80_000_000  // 80ms
            )
        )
        let client = makeClient(store: store, refresh: refresh)

        // 첫 요청은 401, 이후엔 200
        let callCount = LockedCounter()
        StubURLProtocol.handler = { _ in
            let n = callCount.increment()
            if n <= 5 { // 처음 5개의 동시 요청은 모두 401
                return (Data(), 401, nil)
            } else {
                return (Data("{}".utf8), 200, nil)
            }
        }

        async let r1 = client.request(URLRequest(url: testURL))
        async let r2 = client.request(URLRequest(url: testURL))
        async let r3 = client.request(URLRequest(url: testURL))
        async let r4 = client.request(URLRequest(url: testURL))
        async let r5 = client.request(URLRequest(url: testURL))

        let results = try await [r1, r2, r3, r4, r5]
        #expect(results.allSatisfy { $0.1.statusCode == 200 })

        let refreshCalls = await refresh.callCount
        #expect(refreshCalls == 1, "동시 401에도 refresh는 1회만 호출되어야 한다 — 실제: \(refreshCalls)")
    }

    // MARK: - forceRefreshToken

    @Test("forceRefreshToken은 새 토큰 쌍을 저장하고 반환한다")
    func forceRefreshSavesAndReturns() async throws {
        let store = MockTokenStore(accessToken: "OLD", refreshToken: "REFRESH")
        let newPair = TokenPair(accessToken: "NEW_A", refreshToken: "NEW_R")
        let refresh = MockTokenRefreshService(behavior: .success(newPair))
        let client = makeClient(store: store, refresh: refresh)

        let result = try await client.forceRefreshToken()

        #expect(result == newPair)

        let savedAccess = await store.accessToken
        let savedRefresh = await store.refreshToken
        #expect(savedAccess == "NEW_A")
        #expect(savedRefresh == "NEW_R")
    }

    // MARK: - Decodable overload

    @Test("Decodable 오버로드는 응답 JSON을 자동 디코딩한다")
    func decodableOverloadDecodes() async throws {
        let store = MockTokenStore(accessToken: "A", refreshToken: "R")
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in
            (Data("{\"id\":7,\"name\":\"jeong\"}".utf8), 200, nil)
        }

        let dto: SampleDTO = try await client.request(URLRequest(url: testURL))

        #expect(dto.id == 7)
        #expect(dto.name == "jeong")
    }

    // MARK: - Non-2xx error

    @Test("2xx 외 응답은 NetworkError.requestFailed로 변환된다")
    func nonSuccessStatusCodeFails() async {
        let store = MockTokenStore(accessToken: "A", refreshToken: "R")
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = makeClient(store: store, refresh: refresh)

        StubURLProtocol.handler = { _ in (Data(), 500, nil) }

        await #expect(throws: NetworkError.requestFailed(statusCode: 500, data: nil)) {
            _ = try await client.request(URLRequest(url: self.testURL))
        }
    }
}

// MARK: - Helpers

private struct SampleDTO: Decodable, Equatable, Sendable {
    let id: Int
    let name: String
}

/// 동기화된 카운터 — handler 클로저가 multiple thread/queue에서 호출될 수 있으므로 락 필요
private final class LockedCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}
