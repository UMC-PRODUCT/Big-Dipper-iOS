//
//  VerifyEmailCodeRequestDTO.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 이메일 인증 코드 검증 요청 DTO
///
/// `POST /api/v1/auth/email-verification/code`
struct VerifyEmailCodeRequestDTO: Encodable {
    /// 이메일 인증 ID
    let emailVerificationId: String
    /// 사용자가 입력한 인증 코드
    let verificationCode: String
}
