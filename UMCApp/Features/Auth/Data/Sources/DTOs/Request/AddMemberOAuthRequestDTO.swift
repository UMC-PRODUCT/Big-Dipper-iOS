//
//  AddMemberOAuthRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 8/10/26.
//

/// 로그인 OAuth 수단 추가 연동 요청 DTO
///
/// `POST /api/v1/member-oauth`
public struct AddMemberOAuthRequestDTO: Encodable {
    /// 소셜 로그인 시 발급받은 OAuth 검증 토큰
    public let oAuthVerificationToken: String

    public init(oAuthVerificationToken: String) {
        self.oAuthVerificationToken = oAuthVerificationToken
    }
}
