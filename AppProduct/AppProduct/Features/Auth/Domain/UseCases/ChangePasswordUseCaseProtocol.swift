//
//  ChangePasswordUseCaseProtocol.swift
//  AppProduct
//

import Foundation

/// 비밀번호 변경 UseCase Protocol
protocol ChangePasswordUseCaseProtocol {
    /// 비밀번호 변경 실행
    /// - Parameters:
    ///   - currentPassword: 현재 비밀번호 (평문)
    ///   - newPassword: 새 비밀번호 (평문)
    func execute(
        currentPassword: String,
        newPassword: String
    ) async throws
}
