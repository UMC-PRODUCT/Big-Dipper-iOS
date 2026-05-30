//
//  SendEmailVerificationUseCaseProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

// MARK: - Protocol

/// 이메일 인증 발송 UseCase Protocol
protocol SendEmailVerificationUseCaseProtocol {
    /// 이메일 인증 발송
    /// - Parameters:
    ///   - email: 인증할 이메일 주소
    ///   - purpose: 인증 목적 (회원가입/비밀번호 초기화)
    /// - Returns: 이메일 인증 ID
    func execute(
        email: String,
        purpose: EmailVerificationPurpose
    ) async throws -> String
}
