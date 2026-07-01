//
//  NetworkClient.swift
//  CoreNetwork
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import UMCFoundation

/// JWT 인증 기반의 Thread-safe 네트워크 클라이언트입니다.
///
/// 주요 기능:
/// 1. **자동 토큰 관리**: API 요청 시 자동으로 액세스 토큰을 Authorization 헤더에 추가
/// 2. **자동 토큰 갱신**: 401 응답 수신 시 리프레시 토큰으로 자동 갱신 후 재요청
/// 3. **토큰 갱신 중복 방지**: Actor를 사용하여 동시 다발적 401 발생 시에도 토큰 갱신은 1회만 실행
/// 4. **타입 안전한 API 호출**: Codable을 사용한 자동 JSON 파싱
public actor NetworkClient {
    // MARK: - Dependencies

    private let session: URLSession
    private let tokenStore: TokenStore
    private let refreshService: TokenRefreshService
    private let authPolicy: AuthenticationPolicy
    private let maxRetryCount: Int

    /// 현재 진행 중인 토큰 갱신 Task
    ///
    /// - Important:
    ///   - nil이 아니면 이미 토큰 갱신 중 (다른 요청은 이 Task를 대기)
    ///   - nil이면 토큰 갱신 가능 (새 Task 생성)
    ///   - Actor 격리로 Race Condition 방지
    private var refreshTask: Task<TokenPair, Error>?

    // MARK: - Init

    public init(
        session: URLSession = .shared,
        tokenStore: TokenStore,
        refreshService: TokenRefreshService,
        authPolicy: AuthenticationPolicy = DefaultAuthenticationPolicy(),
        maxRetryCount: Int = 1
    ) {
        self.session = session
        self.tokenStore = tokenStore
        self.refreshService = refreshService
        self.authPolicy = authPolicy
        self.maxRetryCount = maxRetryCount
    }

    // MARK: - Public API

    /// API 요청을 실행하고 원시 데이터와 HTTP 응답을 반환합니다.
    public func request(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await performRequst(urlRequest, retryCount: 0)
    }

    /// API 요청을 실행하고 응답을 자동으로 디코딩하여 반환합니다.
    public func request<T: Decodable>(
        _ urlRequest: URLRequest,
        decoder: JSONDecoder = .init()
    ) async throws -> T {
        let (data, _) = try await request(urlRequest)
        return try decoder.decode(T.self, from: data)
    }

    /// 강제로 토큰을 갱신합니다.
    public func forceRefreshToken() async throws -> TokenPair {
        try await refreshTokenIssue(force: true)
    }

    /// 로그아웃 처리를 수행합니다.
    public func logout() async throws {
        refreshTask?.cancel()
        refreshTask = nil
        try await tokenStore.clear()

        #if DEBUG
        print("로그아웃 완료")
        #endif
    }

    /// 현재 로그인 상태를 확인합니다.
    public func isLoggedIn() async -> Bool {
        await tokenStore.getAccessToken() != nil
    }
}

// MARK: - Private Methods

extension NetworkClient {
    private func performRequst(
        _ urlRequest: URLRequest,
        retryCount: Int
    ) async throws -> (Data, HTTPURLResponse) {
        var authenticatedRequest = urlRequest

        // 1. 인증이 필요한 요청인지 확인
        if authPolicy.requireAuthentication(urlRequest) {
            if let token = await tokenStore.getAccessToken() {
                authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        // 2. 네트워크 요청 실행
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: authenticatedRequest)
        } catch let urlError as URLError where urlError.code != .cancelled {
            throw NetworkError.from(urlError: urlError)
        }

        // 3. HTTPURLResponse로 형변환
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // 4. 인증 실패(401) 응답 처리
        if authPolicy.isUnauthorizedResponse(httpResponse) {
            guard retryCount < maxRetryCount else {
                throw NetworkError.maxRetryExceeded
            }

            _ = try await refreshTokenIssue(force: true)

            return try await performRequst(urlRequest, retryCount: retryCount + 1)
        }

        // 5. 성공 응답(2xx) 확인
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, data: data)
        }

        return (data, httpResponse)
    }

    private func refreshTokenIssue(force: Bool = false) async throws -> TokenPair {
        // 이미 토큰 갱신 중인지 확인
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        // 새 토큰 갱신 Task 생성
        let task = Task<TokenPair, Error> {
            defer { refreshTask = nil }

            guard let refreshToken = await tokenStore.getRefreshToken() else {
                throw NetworkError.noRefreshToken
            }

            do {
                let tokenPair = try await refreshService.refresh(refreshToken)
                try await tokenStore.save(
                    accessToken: tokenPair.accessToken,
                    refreshToken: tokenPair.refreshToken
                )
                return tokenPair
            } catch let networkError as NetworkError {
                throw networkError  // 전송 계층 에러(noNetwork/timeout 등)는 그대로 전파
            } catch {
                throw NetworkError.tokenRefreshFailed(reason: error.localizedDescription)
            }
        }

        refreshTask = task
        return try await task.value
    }
}
