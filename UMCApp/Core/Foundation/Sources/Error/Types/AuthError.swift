//
//  AuthError.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/7/25.
//

import Foundation

/// 인증 관련 에러
public enum AuthError: Error, LocalizedError, Equatable {
    /// 로그인되지 않음
    case notLoggedIn

    /// 세션 만료
    case sessionExpired

    /// 인증 정보 오류 (아이디/비밀번호)
    case invalidCredentials

    /// 소셜 로그인 실패
    case socialLoginFailed(provider: String, reason: String?)

    /// 계정 정지
    case accountSuspended(reason: String?)

    /// 가입 승인 대기 중
    case pendingApproval

    /// 가입 거절됨
    case rejected(reason: String?)

    /// 등록되지 않은 사용자 (챌린저로 등록되지 않음)
    case notRegisteredMember

    /// 인증 코드 오류
    case invalidVerificationCode

    /// 인증 코드 만료
    case verificationCodeExpired

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "로그인이 필요합니다."
        case .sessionExpired:
            return "세션이 만료되었습니다."
        case .invalidCredentials:
            return "인증 정보가 올바르지 않습니다."
        case .socialLoginFailed(let provider, let reason):
            return "\(provider) 로그인 실패\(reason.map { ": \($0)" } ?? "")"
        case .accountSuspended(let reason):
            return "계정이 정지되었습니다.\(reason.map { " (\($0))" } ?? "")"
        case .pendingApproval:
            return "가입 승인 대기 중입니다."
        case .rejected(let reason):
            return "가입이 거절되었습니다.\(reason.map { " (\($0))" } ?? "")"
        case .notRegisteredMember:
            return "등록된 챌린저가 아닙니다."
        case .invalidVerificationCode:
            return "인증 번호가 올바르지 않습니다."
        case .verificationCodeExpired:
            return "인증 번호가 만료되었습니다."
        }
    }

    /// 사용자에게 표시할 친화적 메시지
    public var userMessage: String {
        switch self {
        case .sessionExpired:
            return "다시 로그인해주세요."
        case .pendingApproval:
            return "운영진의 승인을 기다리고 있어요."
        case .notRegisteredMember:
            return "등록된 챌린저 정보가 없어요. 운영진에게 문의해주세요."
        case .invalidVerificationCode:
            return "인증 번호를 다시 확인해주세요."
        case .verificationCodeExpired:
            return "인증 번호가 만료되었어요. 다시 요청해주세요."
        default:
            return errorDescription ?? ""
        }
    }
}
