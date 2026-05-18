//
//  ResetPasswordUseCaseProtocol.swift
//  AppProduct
//

import Foundation

/// 비밀번호 초기화 UseCase Protocol
protocol ResetPasswordUseCaseProtocol {
    /// 비밀번호 초기화 실행
    /// - Parameters:
    ///   - emailVerificationToken: `purpose=PASSWORD_RESET`로 발급된 토큰
    ///   - newPassword: 새 비밀번호 (평문)
    func execute(
        emailVerificationToken: String,
        newPassword: String
    ) async throws
}
