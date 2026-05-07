//
//  LoginAppleRequestDTO.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// Apple 소셜 로그인 요청 DTO
///
/// `POST /api/v1/auth/login/apple`
///
/// `email` / `fullName`은 최초 로그인 시에만 Apple이 내려주므로
/// 빈 문자열 또는 nil인 경우 페이로드에서 키를 제거합니다.
struct LoginAppleRequestDTO: Encodable {
    /// Apple Sign In 인증 코드
    let authorizationCode: String
    /// Apple 계정 이메일 (최초 로그인 시)
    let email: String?
    /// Apple 계정 이름 (최초 로그인 시)
    let fullName: String?

    init(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) {
        self.authorizationCode = authorizationCode
        self.email = (email?.isEmpty == false) ? email : nil
        self.fullName = (fullName?.isEmpty == false) ? fullName : nil
    }

    private enum CodingKeys: String, CodingKey {
        case authorizationCode
        case email
        case fullName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authorizationCode, forKey: .authorizationCode)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(fullName, forKey: .fullName)
    }
}
