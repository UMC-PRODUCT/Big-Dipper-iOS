//
//  EmailLoginRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/31/26.
//

/// 이메일(ID/PW) 로그인 API 요청 DTO
///
/// `POST /api/v1/auth/login/email`
public struct EmailLoginRequestDTO: Encodable {

    /// 이메일 주소
    public let email: String
    /// 평문 비밀번호 (TLS 구간 서버 해싱 위임)
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}
