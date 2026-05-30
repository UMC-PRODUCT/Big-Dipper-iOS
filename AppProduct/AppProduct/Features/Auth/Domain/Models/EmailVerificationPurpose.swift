//
//  EmailVerificationPurpose.swift
//  AppProduct
//

import Foundation

/// 이메일 인증 발송 목적
///
/// 서버 `POST /api/v1/auth/email-verification` 요청 시 `purpose` 필드로 전달됩니다.
/// 발급되는 `emailVerificationToken`의 사용 범위가 목적별로 제한됩니다.
enum EmailVerificationPurpose: String, Sendable {
    /// 회원가입
    case register = "REGISTER"
    /// 비밀번호 초기화
    case passwordReset = "PASSWORD_RESET"
}
