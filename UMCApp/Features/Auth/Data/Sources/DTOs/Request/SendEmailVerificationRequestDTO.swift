//
//  SendEmailVerificationRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일 인증 코드 발송 요청 DTO
///
/// `POST /api/v1/auth/email-verification`
public struct SendEmailVerificationRequestDTO: Encodable {
    /// 인증할 이메일 주소
    public let email: String
    /// 인증 목적 ("REGISTER" | "PASSWORD_RESET")
    public let purpose: String

    public init(email: String, purpose: String) {
        self.email = email
        self.purpose = purpose
    }
}
