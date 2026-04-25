//
//  TokenPair.swift
//  CoreNetwork
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

// MARK: - TokenPair

/// JWT 인증에 사용되는 액세스 토큰과 리프레시 토큰 쌍을 나타냅니다.
///
/// 서버로부터 받은 토큰 쌍을 안전하게 저장하고 전달하기 위한 불변(immutable) 구조체입니다.
///
/// - Important:
///   - **Sendable**: 동시성 환경(async/await, Actor)에서 안전하게 사용 가능
///   - **Codable**: JSON 직렬화/역직렬화 지원 (서버 응답 파싱에 사용)
///   - **nonisolated**: Actor 격리 없이 어디서든 접근 가능
public struct TokenPair: Sendable, Codable, Equatable {
    // MARK: - Property
    
    /// API 요청 시 사용하는 액세스 토큰
    public nonisolated let accessToken: String
    
    /// 액세스 토큰 갱신에 사용하는 리프레시 토큰
    public nonisolated let refreshToken: String
    
    // MARK: - Init
    public nonisolated init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
