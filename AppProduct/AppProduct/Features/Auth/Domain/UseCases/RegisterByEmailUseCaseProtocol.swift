//
//  RegisterByEmailUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

// MARK: - Protocol

/// 이메일 회원가입 UseCase Protocol
protocol RegisterByEmailUseCaseProtocol {
    /// 이메일 회원가입 실행
    /// - Parameter request: 회원가입 요청 DTO
    /// - Returns: 생성된 회원 ID + 토큰 쌍
    func execute(
        request: EmailRegisterRequestDTO
    ) async throws -> RegisterByIdPwResult
}
