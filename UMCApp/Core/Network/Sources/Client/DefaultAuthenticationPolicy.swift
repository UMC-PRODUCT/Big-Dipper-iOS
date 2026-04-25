//
//  DefaultAuthenticationPolicy.swift
//  CoreNetwork
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

/// 기본 인증 정책 구현체입니다.
///
/// 가장 일반적인 JWT 인증 방식을 따릅니다:
/// - **모든 API 요청에 인증 필요** (로그인/회원가입 API도 포함)
/// - **401 상태 코드를 인증 실패로 간주**
public struct DefaultAuthenticationPolicy: AuthenticationPolicy, Sendable {
    
    // MARK: - Init
    public nonisolated init() {}
    
    // MARK: - AuthenticationPolicy
    
    /// 모든 요청에 인증이 필요하다고 판단합니다.
    public nonisolated func requireAuthentication(_ request: URLRequest) -> Bool {
        true
    }
    
    /// 401 Unthorized 응답을 인증 실패로 판단합니다.
    public func isUnauthorizedResponse(_ response: HTTPURLResponse) -> Bool {
        response.statusCode == 401
    }
}
