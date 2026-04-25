//
//  AuthSystemFactory.swift
//  CoreNetwork
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

/// 인증 시스템 관련 의존성을 생성하는 팩토리입니다.
///
/// NetworkClient와 관련 의존성(TokenStore, TokenRefreshService)을 올바르게 조립하여 생성합니다.
///
/// - Important:
///   - **프로덕션**: `makeNetworkClient(baseURL:)` 사용
///   - **테스트**: `makeTestNetworkClient(tokenStore:refreshService:)` 사용
///
/// - Usage:
/// ```swift
/// // DIContainer에서 사용
/// final class DIContainer {
///     lazy var networkClient: NetworkClient = {
///         AuthSystemFactory.makeNetworkClient(
///             baseURL: NetworkConfig.baseURL
///         )
///     }()
/// }
/// ```
public enum AuthSystemFactory {

    // MARK: - Factory Methods

    /// 프로덕션 환경용 NetworkClient를 생성합니다.
    ///
    /// 실제 서버와 통신하는 완전한 NetworkClient를 생성합니다.
    ///
    /// ## 구성 요소
    ///
    /// ```
    /// NetworkClient
    ///     ├── URLSession (.shared)
    ///     ├── TokenStore (KeychainTokenStore)
    ///     ├── TokenRefreshService (TokenRefreshServiceImpl)
    ///     └── AuthenticationPolicy (DefaultAuthenticationPolicy)
    /// ```
    public static func makeNetworkClient(
        baseURL: URL,
        session: URLSession = .shared,
        tokenStore: TokenStore? = nil
    ) -> NetworkClient {
        // 1. 토큰 저장소 (외부 주입 또는 Keychain 기반 생성)
        let store = tokenStore ?? KeychainTokenStore()

        // 2. 실제 서버 토큰 갱신 서비스 생성
        let refreshService = TokenRefreshServiceImpl(baseURL: baseURL, session: session)

        // 3. NetworkClient 생성 (모든 의존성 주입)
        return NetworkClient(
            session: session,
            tokenStore: store,
            refreshService: refreshService
        )
    }

    /// 테스트 환경용 NetworkClient를 생성합니다.
    ///
    /// Mock TokenStore와 TokenRefreshService를 주입하여 테스트 가능한 NetworkClient를 생성합니다.
    public static func makeTestNetworkClient(
        tokenStore: TokenStore,
        refreshService: TokenRefreshService
    ) -> NetworkClient {
        NetworkClient(
            session: .shared,
            tokenStore: tokenStore,
            refreshService: refreshService
        )
    }
}
