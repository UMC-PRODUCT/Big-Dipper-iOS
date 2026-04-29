//
//  RegisterByIdPwUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

// MARK: - Protocol

/// ID/PW 회원가입 UseCase Protocol
protocol RegisterByIdPwUseCaseProtocol {
    /// ID/PW 회원가입 실행
    /// - Parameter request: 회원가입 요청 DTO
    /// - Returns: 생성된 회원 ID + 토큰 쌍
    func execute(
        request: RegisterByIdPwRequestDTO
    ) async throws -> RegisterByIdPwResult
}
