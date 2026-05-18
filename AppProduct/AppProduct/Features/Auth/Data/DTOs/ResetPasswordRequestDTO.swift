//
//  ResetPasswordRequestDTO.swift
//  AppProduct
//

import Foundation

/// 비밀번호 초기화 요청 DTO
///
/// `PATCH /api/v1/auth/password/reset`
/// `purpose=PASSWORD_RESET`으로 발급된 토큰만 사용 가능.
struct ResetPasswordRequestDTO: Encodable {
    /// 비밀번호 초기화용 이메일 인증 토큰
    let emailVerificationToken: String
    /// 새 비밀번호 (평문)
    let newPassword: String
}
