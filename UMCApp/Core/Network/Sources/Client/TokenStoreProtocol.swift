//
//  TokenStoreProtocol.swift
//  CoreNetwork
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

// MARK: - TokenStore

/// JWT 토큰을 안전하게 저장하고 관리하는 저장소 프로토콜입니다.
///
/// 액세스 토큰과 리프레시 토큰을 영구 저장소(Keychain, UserDefaults 등)에 저장하고,
/// NetworkClient가 인증이 필요한 API 호출 시 토큰을 제공합니다.
///
/// - Important:
///   - **Sendable**: Actor와 안전하게 상호작용 가능
///   - **async 메서드**: 저장소 접근은 비동기로 처리 (I/O 작업)
///   - **Keychain 권장**: 민감한 토큰 정보는 Keychain에 저장 필수
public protocol TokenStore: Sendable {
    /// 저장된 액세스 토큰 반환
    func getAccessToken() async -> String?
    
    /// 저장된 리프레시 토큰을 반환
    func getRefreshToken() async -> String?
    
    /// 액세스 토큰과 리프레시 토큰을 저장
    func save(accessToken: String, refreshToken: String) async throws
    
    /// 저장된 모든 토큰 삭제
    func clear() async throws
}

// MARK: - TokenRefreshService

/// 리프레시 토큰으로 새로운 토큰 쌍을 발급받는 서비스 프로토콜입니다.
///
/// 액세스 토큰 만료(401) 시 서버의 토큰 갱신 API를 호출하여
/// 새로운 액세스 토큰과 리프레시 토큰을 발급받습니다.
public protocol TokenRefreshService: Sendable {
    /// 리프레시 토큰으로 새로운 토큰 쌍을 발급받습니다.
    ///
    /// - Throws:
    ///   - `NetworkError.tokenRefreshFailed`: 토큰 갱신 API 호출 실패
    func refresh(_ refreshToken: String) async throws -> TokenPair
}

// MARK: - AuthenticationPolicy

/// API 요청의 인증 정책을 정의하는 프로토콜입니다.
///
/// 어떤 요청에 인증이 필요한지, 어떤 응답이 인증 실패인지를 판단하는 로직을 제공합니다.
public protocol AuthenticationPolicy: Sendable {
    /// 주어진 요청에 인증(Authorization 헤더)이 필요한지 판단합니다.
    nonisolated func requireAuthentication(_ request: URLRequest) -> Bool

    /// 주어진 응답이 인증 실패(Unauthorized) 응답인지 판단합니다.
    nonisolated func isUnauthorizedResponse(_ response: HTTPURLResponse) -> Bool
}
