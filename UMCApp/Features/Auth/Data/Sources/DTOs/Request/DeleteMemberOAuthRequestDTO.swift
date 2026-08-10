//
//  DeleteMemberOAuthRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 8/10/26.
//

/// 로그인 OAuth 수단 연동 해제 요청 DTO
///
/// `DELETE /api/v1/member-oauth/{memberOAuthId}`
public struct DeleteMemberOAuthRequestDTO: Encodable {
    /// Google 연동 해제 검증용 액세스 토큰
    public let googleAccessToken: String?
    /// Kakao 연동 해제 검증용 액세스 토큰
    public let kakaoAccessToken: String?

    public init(googleAccessToken: String?, kakaoAccessToken: String?) {
        self.googleAccessToken = googleAccessToken
        self.kakaoAccessToken = kakaoAccessToken
    }
}
