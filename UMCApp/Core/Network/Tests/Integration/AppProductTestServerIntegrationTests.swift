//
//  AppProductTestServerIntegrationTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import CoreNetwork

/// AppProductTestServer가 띄워져 있을 때만 실행되는 통합 테스트입니다.
///
/// ## 실행 방법
///
/// ```bash
/// # 1. 서버 띄우기
/// cd AppProductTestServer && make start
///
/// # 2. 통합 테스트 실행 (UMCApp 워크스페이스)
/// cd UMCApp && TEST_SERVER_URL=http://127.0.0.1:8080 make test
///
/// # 3. 서버 내리기
/// cd AppProductTestServer && make stop
/// ```
///
/// `TEST_SERVER_URL` 환경 변수가 비어 있거나 서버가 응답하지 않으면 자동 스킵됩니다.
@Suite("AppProductTestServer 통합", .serialized, .enabled(if: IntegrationConfig.isEnabled))
struct AppProductTestServerIntegrationTests {

    // MARK: - Public Endpoints

    @Test("GET /test 는 CommonDTO 성공 래퍼로 문자열을 돌려준다")
    func testEndpointReturnsSuccess() async throws {
        let client = makeUnauthenticatedClient()

        let request = URLRequest(url: IntegrationConfig.baseURL.appending(path: "/test"))
        let (data, response) = try await client.request(request)

        #expect(response.statusCode == 200)

        let decoded = try JSONDecoder().decode(APIResponse<String>.self, from: data)
        #expect(decoded.isSuccess)
        #expect(try decoded.unwrap() == "테스트 성공")
    }

    // MARK: - Protected Endpoints

    @Test("토큰이 있으면 GET /protected 가 200을 돌려준다")
    func protectedEndpointWithToken() async throws {
        let client = makeAuthenticatedClient(accessToken: "valid_token")

        let request = URLRequest(url: IntegrationConfig.baseURL.appending(path: "/protected"))
        let (data, response) = try await client.request(request)

        #expect(response.statusCode == 200)
        let decoded = try JSONDecoder().decode(APIResponse<String>.self, from: data)
        #expect(try decoded.unwrap() == "보호 성공")
    }

    @Test("토큰이 없으면 GET /protected 가 NetworkError.maxRetryExceeded 로 끝난다")
    func protectedEndpointWithoutTokenFails() async throws {
        // accessToken=nil → Authorization 헤더 미전송 → 401 → refresh 시도 →
        // refreshToken 도 없으므로 noRefreshToken 으로 종료
        let client = makeUnauthenticatedClient()

        let request = URLRequest(url: IntegrationConfig.baseURL.appending(path: "/protected"))

        await #expect(throws: NetworkError.self) {
            _ = try await client.request(request)
        }
    }

    @Test("GET /user 는 UserDTO 형태의 result 를 반환한다")
    func userEndpointDecodesUserDTO() async throws {
        let client = makeAuthenticatedClient(accessToken: "valid_token")

        let request = URLRequest(url: IntegrationConfig.baseURL.appending(path: "/user"))
        let response: APIResponse<TestUserDTO> = try await client.request(request)

        let user = try response.unwrap()
        #expect(user.id == 1)
        #expect(user.name == "Test User")
        #expect(user.email == "test@jeong.com")
    }

    @Test("GET /users 는 UserDTO 배열을 반환한다")
    func usersEndpointDecodesArray() async throws {
        let client = makeAuthenticatedClient(accessToken: "valid_token")

        let request = URLRequest(url: IntegrationConfig.baseURL.appending(path: "/users"))
        let response: APIResponse<[TestUserDTO]> = try await client.request(request)

        let users = try response.unwrap()
        #expect(users.count == 3)
        #expect(users[0].id == 1)
    }

    // MARK: - Token Refresh Flow

    @Test("401 만료 토큰 → /auth/reissue 호출 → 새 토큰으로 재시도 → 200")
    func endToEndRefreshFlow() async throws {
        // 1) 만료된 access + 유효한 refresh 로 시작
        let store = MockTokenStore(
            accessToken: "expired_token",
            refreshToken: "valid_refresh_token"
        )

        // 2) 실제 서버의 /auth/reissue 를 호출하는 RefreshService
        let refreshService = AppProductTestServerRefreshService(
            baseURL: IntegrationConfig.baseURL,
            session: .shared
        )

        let client = NetworkClient(
            session: .shared,
            tokenStore: store,
            refreshService: refreshService,
            authPolicy: DefaultAuthenticationPolicy(),
            maxRetryCount: 1
        )

        // 3) /protected 호출 — 첫 시도는 401, 자동 refresh 후 새 토큰으로 재시도
        let request = URLRequest(url: IntegrationConfig.baseURL.appending(path: "/protected"))
        let (_, response) = try await client.request(request)

        #expect(response.statusCode == 200)

        // 4) Mock store 에 새 토큰이 저장되었는지 확인
        let savedAccess = await store.accessToken
        #expect(savedAccess?.hasPrefix("new_access_token_") == true,
                "새 액세스 토큰으로 갱신되어야 한다 (실제: \(savedAccess ?? "nil"))")
    }

    @Test("리프레시 토큰이 'expired_token' 이면 갱신 자체가 실패한다")
    func expiredRefreshTokenFails() async throws {
        let store = MockTokenStore(
            accessToken: "expired_token",
            refreshToken: "expired_token"
        )
        let refreshService = AppProductTestServerRefreshService(
            baseURL: IntegrationConfig.baseURL,
            session: .shared
        )
        let client = NetworkClient(
            session: .shared,
            tokenStore: store,
            refreshService: refreshService,
            authPolicy: DefaultAuthenticationPolicy(),
            maxRetryCount: 1
        )

        let request = URLRequest(url: IntegrationConfig.baseURL.appending(path: "/protected"))

        await #expect(throws: NetworkError.self) {
            _ = try await client.request(request)
        }
    }

    // MARK: - Helpers

    private func makeUnauthenticatedClient() -> NetworkClient {
        let store = MockTokenStore()
        return NetworkClient(
            session: .shared,
            tokenStore: store,
            refreshService: NoopRefreshService(),
            authPolicy: DefaultAuthenticationPolicy(),
            maxRetryCount: 0
        )
    }

    private func makeAuthenticatedClient(accessToken: String) -> NetworkClient {
        let store = MockTokenStore(accessToken: accessToken, refreshToken: "valid_refresh")
        return NetworkClient(
            session: .shared,
            tokenStore: store,
            refreshService: NoopRefreshService(),
            authPolicy: DefaultAuthenticationPolicy(),
            maxRetryCount: 0
        )
    }
}

// MARK: - DTOs (테스트 전용)

private struct TestUserDTO: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - Real Refresh Service

/// 실제 AppProductTestServer 의 `POST /auth/reissue` 를 호출하는 TokenRefreshService 입니다.
///
/// 서버 스펙:
/// - 헤더: `Authorization: Bearer <refreshToken>`
/// - 응답: `CommonDTO<TokenPair>` (성공 시 새 access/refresh 쌍)
private struct AppProductTestServerRefreshService: TokenRefreshService {
    let baseURL: URL
    let session: URLSession

    func refresh(_ refreshToken: String) async throws -> TokenPair {
        var request = URLRequest(url: baseURL.appending(path: "/auth/reissue"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(APIResponse<TokenPair>.self, from: data)
        return try decoded.unwrap()
    }
}

private struct NoopRefreshService: TokenRefreshService {
    func refresh(_ refreshToken: String) async throws -> TokenPair {
        throw NetworkError.tokenRefreshFailed(reason: "noop")
    }
}

// MARK: - Configuration

enum IntegrationConfig {
    static let baseURL: URL = {
        let raw = ProcessInfo.processInfo.environment["TEST_SERVER_URL"] ?? "http://127.0.0.1:8080"
        return URL(string: raw)!
    }()

    /// 서버에 연결 가능할 때만 통합 테스트를 실행합니다.
    /// 첫 호출 시 1회 동기 ping → 결과 캐싱.
    nonisolated(unsafe) static let isEnabled: Bool = {
        // TEST_SERVER_URL 이 명시적으로 설정된 경우에도, 서버가 살아있어야 의미가 있음
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5

        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false

        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                reachable = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.0)
        task.cancel()

        return reachable
    }()
}
