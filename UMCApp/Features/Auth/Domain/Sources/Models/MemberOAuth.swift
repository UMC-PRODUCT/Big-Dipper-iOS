//
//  MemberOAuth.swift
//  AuthDomain
//
//  Created by euijjang97 on 8/10/26.
//

/// 회원 OAuth 연동 정보.
public struct MemberOAuth: Equatable, Sendable {

    // MARK: - Property

    /// OAuth 연동 ID (서버 응답 String 기준)
    public let memberOAuthId: String

    /// 회원 ID (서버 응답 String 기준)
    public let memberId: String

    /// OAuth 제공자 (APPLE, KAKAO, GOOGLE)
    public let provider: OAuthProvider

    // MARK: - Init

    public init(memberOAuthId: String, memberId: String, provider: OAuthProvider) {
        self.memberOAuthId = memberOAuthId
        self.memberId = memberId
        self.provider = provider
    }
}
