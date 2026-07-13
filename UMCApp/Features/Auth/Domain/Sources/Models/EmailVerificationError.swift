//
//  EmailVerificationError.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

import Foundation

/// 이메일 인증 관련 도메인 에러.
///
/// 서버 코드(AUTHENTICATION-0025/0026/0027)를 Data 레이어가 매핑해 던진다.
public enum EmailVerificationError: Error, LocalizedError, Equatable, Sendable {
    /// 이미 가입된 이메일 (AUTHENTICATION-0026)
    case emailAlreadyExists
    /// 인증 요청이 너무 잦음 (AUTHENTICATION-0027)
    case throttled
    /// 이메일 형식 오류 (AUTHENTICATION-0025)
    case invalidEmailFormat

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .emailAlreadyExists:
            return "이미 가입된 이메일입니다."
        case .throttled:
            return "잠시 후 다시 시도해주세요."
        case .invalidEmailFormat:
            return "이메일 형식이 올바르지 않습니다."
        }
    }

    /// 사용자에게 표시할 안내 메시지
    public var userMessage: String {
        errorDescription ?? ""
    }
}
