//
//  MemberOAuthDTO.swift
//  AuthData
//
//  Created by euijjang97 on 8/10/26.
//

import AuthDomain
import UMCFoundation

/// 회원 OAuth 연동 정보 API 응답 DTO
///
/// `GET /api/v1/member-oauth/me`, `POST /api/v1/member-oauth` 응답 요소.
public struct MemberOAuthDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// OAuth 연동 ID (서버 응답 String 기준)
    public let memberOAuthId: String
    /// 회원 ID (서버 응답 String 기준)
    public let memberId: String
    /// OAuth 제공자 raw 문자열 (KAKAO, APPLE, GOOGLE)
    public let provider: String

    private enum CodingKeys: String, CodingKey {
        case memberOAuthId
        case memberId
        case provider
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 연동 해제 경로(/member-oauth/{id})에 그대로 실리는 필수 식별자라 누락되면 throw한다.
        memberOAuthId = try container.decodeFlexibleString(forKey: .memberOAuthId)
        memberId = container.decodeFlexibleStringOrEmpty(forKey: .memberId)
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberOAuthId, forKey: .memberOAuthId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(provider, forKey: .provider)
    }

    // MARK: - Mapping

    public func toDomain() -> MemberOAuth {
        MemberOAuth(
            memberOAuthId: memberOAuthId,
            memberId: memberId,
            provider: OAuthProvider(raw: provider)
        )
    }
}
