//
//  NetworkClient.swift
//  AppProduct
//
//  Created by euijjang97 on 1/9/26.
//

import Foundation

/// JWT 인증 기반의 Thread-safe 네트워크 클라이언트입니다.
///
/// 주요 기능:
/// 1. **자동 토큰 관리**: API 요청 시 자동으로 액세스 토큰을 Authorization 헤더에 추가
/// 2. **자동 토큰 갱신**: 401 응답 수신 시 리프레시 토큰으로 자동 갱신 후 재요청
/// 3. **토큰 갱신 중복 방지**: Actor를 사용하여 동시 다발적 401 발생 시에도 토큰 갱신은 1회만 실행
/// 4. **타입 안전한 API 호출**: Codable을 사용한 자동 JSON 파싱
///
/// - Important:
///   - **Actor**: Thread-safe한 토큰 갱신 보장 (Race Condition 방지)
///   - **Sendable**: 동시성 환경에서 안전하게 사용 가능
///   - **의존성 주입**: TokenStore, TokenRefreshService, AuthenticationPolicy 주입 필요
///
/// ## 토큰 갱신 메커니즘
///
/// ```
/// API 요청 → 401 응답 수신
///     ↓
/// refreshTask 확인
///     ↓
/// ┌─────────────┬─────────────┐
/// │ Task 있음   │ Task 없음   │
/// ├─────────────┼─────────────┤
/// │ 기존 Task   │ 새 Task     │
/// │ 대기 후     │ 생성하여    │
/// │ 결과 재사용 │ 토큰 갱신   │
/// └─────────────┴─────────────┘
///     ↓
/// 새 액세스 토큰으로 재요청
/// ```
///
/// ## 사용 예시
///
/// ### 1. NetworkClient 초기화
/// ```swift
/// // DIContainer에서 초기화
/// let networkClient = NetworkClient(
///     tokenStore: KeychainTokenStore(),
///     refreshService: DefaultTokenRefreshService()
/// )
/// ```
///
/// ### 2. 기본 API 호출
/// ```swift
/// // URLRequest 생성
/// var request = URLRequest(url: URL(string: "https://api.example.com/users/me")!)
/// request.httpMethod = "GET"
///
/// // Data + HTTPURLResponse 반환
/// let (data, response) = try await networkClient.request(request)
/// let user = try JSONDecoder().decode(User.self, from: data)
/// ```
///
/// ### 3. 자동 디코딩 API 호출
/// ```swift
/// struct User: Codable {
///     let id: Int
///     let name: String
/// }
///
/// let user: User = try await networkClient.request(request)
/// print(user.name)
/// ```
///
/// ### 4. 로그인 처리
/// ```swift
/// // 로그인 API 호출 (TokenStore에 자동 저장됨)
/// struct LoginResponse: Codable {
///     let accessToken: String
///     let refreshToken: String
/// }
///
/// let response: LoginResponse = try await networkClient.request(loginRequest)
/// try await tokenStore.save(
///     accessToken: response.accessToken,
///     refreshToken: response.refreshToken
/// )
/// ```
///
/// ### 5. 로그아웃 처리
/// ```swift
/// try await networkClient.logout()  // 토큰 삭제 + 갱신 Task 취소
/// ```
///
/// ### 6. 에러 처리
/// ```swift
/// do {
///     let user: User = try await networkClient.request(request)
/// } catch NetworkError.unauthorized {
///     // 로그인 필요
///     navigateToLogin()
/// } catch NetworkError.tokenRefreshFailed {
///     // 토큰 갱신 실패 → 재로그인 필요
///     navigateToLogin()
/// } catch NetworkError.requestFailed(let statusCode, let data) {
///     // 서버 에러 처리
///     if statusCode == 404 {
///         print("리소스를 찾을 수 없습니다")
///     }
/// } catch {
///     // 기타 에러 (네트워크 연결 끊김 등)
///     print("네트워크 에러: \(error)")
/// }
/// ```
///
/// ## 동시 요청 시나리오
///
/// ```
/// 시간 →
///
/// Request A ──401──┐
/// Request B ──401──┤→ refreshTask 생성 (1개만!)
/// Request C ──401──┘     ↓
///                    토큰 갱신 완료
///                         ↓
/// Request A ──────────→ 재요청 (새 토큰)
/// Request B ──────────→ 재요청 (새 토큰)
/// Request C ──────────→ 재요청 (새 토큰)
/// ```
actor NetworkClient {
    // MARK: - Dependencies

    /// URLSession 인스턴스 (네트워크 요청 실행)
    ///
    /// - Note: 테스트 시 커스텀 URLSession 주입 가능
    private let session: URLSession

    /// 토큰 저장소 (액세스/리프레시 토큰 관리)
    ///
    /// - Note: Keychain 기반 구현 권장
    private let tokenStore: TokenStore

    /// 토큰 갱신 서비스 (리프레시 토큰으로 새 토큰 쌍 발급)
    ///
    /// - Note: 서버의 /auth/refresh API 호출
    private let refreshService: TokenRefreshService

    /// 인증 정책 (어떤 요청에 인증이 필요한지 판단)
    ///
    /// - Note: 기본값은 모든 요청에 인증 필요
    private let authPolicy: AuthenticationPolicy

    /// 최대 재시도 횟수 (401 발생 시)
    ///
    /// - Note: 기본값 1회 (토큰 갱신 1회 후 재요청)
    private let maxRetryCount: Int

    /// 현재 진행 중인 토큰 갱신 Task
    ///
    /// - Important:
    ///   - nil이 아니면 이미 토큰 갱신 중 (다른 요청은 이 Task를 대기)
    ///   - nil이면 토큰 갱신 가능 (새 Task 생성)
    ///   - Actor 격리로 Race Condition 방지
    private var refreshTask: Task<TokenPair, Error>?

    // MARK: - Initializer

    /// NetworkClient 초기화
    ///
    /// - Parameters:
    ///   - session: URLSession (기본값: .shared)
    ///   - tokenStore: 토큰 저장소 (필수)
    ///   - refreshService: 토큰 갱신 서비스 (필수)
    ///   - authPolicy: 인증 정책 (기본값: DefaultAuthenticationPolicy)
    ///   - maxRetryCount: 최대 재시도 횟수 (기본값: 1)
    ///
    /// - Important: DIContainer에서 싱글톤으로 관리 권장
    init(
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
    ///
    /// - Parameter urlRequest: 실행할 URLRequest
    ///
    /// - Returns: (응답 데이터, HTTPURLResponse) 튜플
    ///
    /// - Throws:
    ///   - `NetworkError.unauthorized`: 인증 필요 (토큰 없음)
    ///   - `NetworkError.tokenRefreshFailed`: 토큰 갱신 실패
    ///   - `NetworkError.requestFailed`: API 요청 실패 (2xx 이외)
    ///   - `NetworkError.invalidResponse`: 잘못된 응답
    ///   - `NetworkError.maxRetryExceeded`: 재시도 횟수 초과
    ///
    /// - Important:
    ///   - 401 응답 수신 시 자동으로 토큰 갱신 후 재요청
    ///   - Authorization 헤더는 자동으로 추가됨 (authPolicy가 true 반환 시)
    ///
    /// - Usage:
    /// ```swift
    /// let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    /// let (data, response) = try await networkClient.request(request)
    /// print("Status: \(response.statusCode)")
    /// ```
    func request(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await performRequst(urlRequest, retryCount: 0)
    }

    /// API 요청을 실행하고 응답을 자동으로 디코딩하여 반환합니다.
    ///
    /// - Parameters:
    ///   - urlRequest: 실행할 URLRequest
    ///   - decoder: JSON 디코더 (기본값: JSONDecoder())
    ///
    /// - Returns: 디코딩된 객체 (Decodable 타입)
    ///
    /// - Throws:
    ///   - `NetworkError.*`: 네트워크 에러
    ///   - `DecodingError.*`: JSON 디코딩 에러
    ///
    /// - Important: 가장 자주 사용하는 API 호출 방식
    ///
    /// - Usage:
    /// ```swift
    /// struct User: Codable {
    ///     let id: Int
    ///     let name: String
    /// }
    ///
    /// let request = URLRequest(url: URL(string: "https://api.example.com/users/me")!)
    /// let user: User = try await networkClient.request(request)
    /// print(user.name)
    /// ```
    func request<T: Decodable>(_ urlRequest: URLRequest, decoder: JSONDecoder = .init()) async throws -> T {
        let (data, _) = try await request(urlRequest)
        return try decoder.decode(T.self, from: data)
    }

    /// 강제로 토큰을 갱신합니다.
    ///
    /// - Returns: 새로 발급받은 토큰 쌍
    ///
    /// - Throws:
    ///   - `NetworkError.noRefreshToken`: 리프레시 토큰 없음
    ///   - `NetworkError.tokenRefreshFailed`: 토큰 갱신 실패
    ///
    /// - Note:
    ///   - 일반적으로 사용하지 않음 (401 발생 시 자동 갱신)
    ///   - 앱 포그라운드 진입 시 미리 갱신하는 용도로 사용 가능
    ///
    /// - Usage:
    /// ```swift
    /// // 앱 포그라운드 진입 시 토큰 미리 갱신
    /// NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification) { _ in
    ///     Task {
    ///         try? await networkClient.forceRefreshToken()
    ///     }
    /// }
    /// ```
    func forceRefreshToken() async throws -> TokenPair {
        try await refreshTokenIssue(force: true)
    }

    /// 로그아웃 처리를 수행합니다.
    ///
    /// 1. 진행 중인 토큰 갱신 Task 취소
    /// 2. 저장된 모든 토큰 삭제
    /// 3. 세션 단위 `AppStorage` 값(역할/조직/기수 등) 일괄 삭제
    ///
    /// - Throws: TokenStore.clear() 실패 시 에러 발생
    ///
    /// - Important:
    ///   - 로그아웃 후 API 요청 시 인증 에러 발생
    ///   - 로그인 화면으로 이동 필요
    ///   - `AppStorage` 의 역할/조직 정보를 함께 비워, 다른 계정으로
    ///     재로그인할 때 이전 사용자의 권한이 잔존하지 않도록 보장
    ///
    /// - Usage:
    /// ```swift
    /// // 로그아웃 버튼 탭
    /// func logoutButtonTapped() async {
    ///     do {
    ///         try await networkClient.logout()
    ///         navigateToLogin()
    ///     } catch {
    ///         print("로그아웃 실패: \(error)")
    ///     }
    /// }
    /// ```
    func logout() async throws {
        refreshTask?.cancel()
        refreshTask = nil
        try await tokenStore.clear()
        AppStorageKey.clearSessionScopedValues()

        #if DEBUG
        print("로그아웃 완료")
        #endif
    }

    /// 현재 로그인 상태를 확인합니다.
    ///
    /// - Returns:
    ///   - `true`: 액세스 토큰이 저장되어 있음 (로그인 상태)
    ///   - `false`: 액세스 토큰이 없음 (로그아웃 상태)
    ///
    /// - Note:
    ///   - 토큰 유효성은 검증하지 않음 (만료된 토큰도 true 반환)
    ///   - 실제 API 호출 시 만료 여부 확인됨
    ///
    /// - Usage:
    /// ```swift
    /// // 앱 시작 시 로그인 상태 확인
    /// if await networkClient.isLoggedIn() {
    ///     navigateToHome()
    /// } else {
    ///     navigateToLogin()
    /// }
    /// ```
    func isLoggedIn() async -> Bool {
        await tokenStore.getAccessToken() != nil
    }

}

// MARK: - Private Methods

extension NetworkClient {
    /// 실제 네트워크 요청을 수행합니다. (내부 구현)
    ///
    /// - Parameters:
    ///   - urlRequest: 실행할 URLRequest
    ///   - retryCount: 현재 재시도 횟수
    ///
    /// - Returns: (응답 데이터, HTTPURLResponse) 튜플
    ///
    /// - Throws: NetworkError.*
    ///
    /// - Important:
    ///   - 401 응답 시 자동으로 토큰 갱신 후 재귀 호출
    ///   - retryCount가 maxRetryCount 초과 시 에러 발생
    ///
    /// - Note: 외부에서 직접 호출하지 않음 (request()에서 호출)
    private func performRequst(
        _ urlRequest: URLRequest,
        retryCount: Int
    ) async throws -> (Data, HTTPURLResponse) {
        var authenticatedRequest = urlRequest

        // 1. 인증이 필요한 요청인지 확인
        if authPolicy.requireAuthentication(urlRequest) {
            if let token = await tokenStore.getAccessToken() {
                // 액세스 토큰을 Authorization 헤더에 추가
                authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        // 2. 네트워크 요청 실행
        let (data, response) = try await session.data(for: authenticatedRequest)

        // 3. HTTPURLResponse로 형변환
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // 4. 인증 실패(401) 응답 처리
        if authPolicy.isUnauthorizedResponse(httpResponse) {
            // 최대 재시도 횟수 확인
            guard retryCount < maxRetryCount else {
                throw NetworkError.maxRetryExceeded
            }

            // 토큰 갱신 (여러 요청이 동시에 401을 받아도 1회만 갱신)
            _ = try await refreshTokenIssue(force: true)

            // 새 토큰으로 재요청 (retryCount 증가)
            return try await performRequst(urlRequest, retryCount: retryCount + 1)
        }

        // 5. 성공 응답(2xx) 확인
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, data: data)
        }

        return (data, httpResponse)
    }

    /// 토큰 갱신을 수행합니다. (내부 구현)
    ///
    /// - Parameter force: 사용되지 않음 (하위 호환성 유지용)
    ///
    /// - Returns: 새로 발급받은 TokenPair
    ///
    /// - Throws:
    ///   - `NetworkError.noRefreshToken`: 리프레시 토큰 없음
    ///   - `NetworkError.tokenRefreshFailed`: 갱신 실패
    ///
    /// - Important:
    ///   - **중복 방지**: refreshTask가 있으면 기존 Task 대기, 없으면 새 Task 생성
    ///   - **Actor 격리**: 동시 다발적 호출에도 안전
    ///
    /// ## 동작 흐름
    ///
    /// ```
    /// refreshTokenIssue() 호출
    ///     ↓
    /// refreshTask 확인
    ///     ↓
    /// ┌──────────────┬──────────────┐
    /// │ Task 있음    │ Task 없음    │
    /// ├──────────────┼──────────────┤
    /// │ 기존 Task    │ 새 Task 생성 │
    /// │ 결과 대기    │ 토큰 갱신    │
    /// │ (중복 방지)  │ 실행         │
    /// └──────────────┴──────────────┘
    ///     ↓
    /// TokenPair 반환
    /// ```
    ///
    /// - Note: 외부에서 직접 호출하지 않음 (performRequest()에서 호출)
    private func refreshTokenIssue(force: Bool = false) async throws -> TokenPair {
        // 이미 토큰 갱신 중인지 확인
        if let existingTask = refreshTask {
            // 기존 Task의 결과를 대기하여 반환 (중복 갱신 방지)
            return try await existingTask.value
        }

        // 새 토큰 갱신 Task 생성
        let task = Task<TokenPair, Error> {
            // Task 완료 시 refreshTask를 nil로 초기화
            defer { refreshTask = nil }

            // 1. 리프레시 토큰 확인
            guard let refreshToken = await tokenStore.getRefreshToken() else {
                throw NetworkError.noRefreshToken
            }

            do {
                // 2. 서버에 토큰 갱신 요청
                let tokenPair = try await refreshService.refresh(refreshToken)

                // 3. 새 토큰 쌍 저장
                try await tokenStore.save(
                    accessToken: tokenPair.accessToken,
                    refreshToken: tokenPair.refreshToken
                )

                return tokenPair
            } catch {
                throw NetworkError.tokenRefreshFailed(reason: error.localizedDescription)
            }
        }

        // refreshTask에 Task 저장 (다른 요청이 대기할 수 있도록)
        refreshTask = task
        return try await task.value
    }
}
