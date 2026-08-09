//
//  LoginKakaoRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

/// 카카오 소셜 로그인 요청 DTO
///
/// `POST /api/v1/auth/login/kakao`
public struct LoginKakaoRequestDTO: Encodable {
    /// 카카오 SDK 액세스 토큰
    public let accessToken: String
    /// 카카오 계정 이메일
    public let email: String
    /// 클라이언트 플랫폼 (`ANDROID` / `IOS` / `WEB`)
    ///
    /// 서버가 로그인 시 전달된 값을 Access Token claim에 넣어
    /// 이후 API 호출을 디바이스 유형별로 라벨링한다.
    public let clientType: String

    public init(accessToken: String, email: String, clientType: String = "IOS") {
        self.accessToken = accessToken
        self.email = email
        self.clientType = clientType
    }
}
