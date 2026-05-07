//
//  SendEmailVerificationRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/7/26.
//

import Foundation

/// 이메일 인증 코드 발송 요청 DTO
///
/// `POST /api/v1/auth/email-verification`
struct SendEmailVerificationRequestDTO: Encodable {
    /// 인증할 이메일 주소
    let email: String
}
