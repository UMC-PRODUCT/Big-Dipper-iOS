//
//  OAuthLoginResponseDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

import CoreNetwork

/// OAuth 소셜 로그인 API 응답 DTO
///
/// 서버 응답 result 구조:
/// - 기존 회원: `accessToken` + `refreshToken` 반환
/// - 신규 회원: `oAuthVerificationToken`만 반환
///
/// - Note: 정수 필드가 없어 절대규칙 #3의 `decodeIntFlexibleIfPresent` 적용 대상이 아니다
///   (`docs/claude/response-dto-decoding.md` 원칙 2 — Int 필드가 있을 때만 custom Codable 필수).
public struct OAuthLoginResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// JWT 액세스 토큰 (기존 회원만)
    public let accessToken: String?
    /// JWT 리프레시 토큰 (기존 회원만)
    public let refreshToken: String?
    /// OAuth 인증 토큰 (신규 회원만 - 회원가입 플로우용)
    public let oAuthVerificationToken: String?
}

// MARK: - Mapping

extension OAuthLoginResponseDTO {
    /// 기존 회원 로그인 성공 시 발급된 토큰 쌍. 신규 회원인 경우 `nil`.
    var tokenPair: TokenPair? {
        guard let accessToken, let refreshToken else { return nil }
        return TokenPair(accessToken: accessToken, refreshToken: refreshToken)
    }
}
