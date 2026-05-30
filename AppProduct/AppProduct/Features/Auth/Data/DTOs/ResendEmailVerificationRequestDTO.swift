//
//  ResendEmailVerificationRequestDTO.swift
//  AppProduct
//

import Foundation

/// 이메일 인증 코드 재전송 요청 DTO
///
/// `POST /api/v1/auth/email-verification/resend`
struct ResendEmailVerificationRequestDTO: Encodable {
    /// 재전송 대상 이메일 인증 ID
    let emailVerificationId: String
}
