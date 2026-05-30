//
//  ResendEmailVerificationUseCaseProtocol.swift
//  AppProduct
//

import Foundation

/// 이메일 인증 코드 재전송 UseCase Protocol
protocol ResendEmailVerificationUseCaseProtocol {
    /// 인증 코드 재전송
    /// - Parameter emailVerificationId: 발송 시 발급된 인증 ID
    func execute(emailVerificationId: String) async throws
}
