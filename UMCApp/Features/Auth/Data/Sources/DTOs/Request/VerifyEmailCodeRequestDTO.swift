//
//  VerifyEmailCodeRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일 인증 코드 검증 요청 DTO
///
/// `POST /api/v1/auth/email-verification/code`
public struct VerifyEmailCodeRequestDTO: Encodable {
    /// 이메일 인증 ID
    public let emailVerificationId: String
    /// 사용자가 입력한 인증 코드
    public let verificationCode: String

    public init(emailVerificationId: String, verificationCode: String) {
        self.emailVerificationId = emailVerificationId
        self.verificationCode = verificationCode
    }
}
