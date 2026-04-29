//
//  LoginByIdPwUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

// MARK: - Protocol

/// ID/PW 로그인 UseCase Protocol
protocol LoginByIdPwUseCaseProtocol {
    /// ID/PW 로그인 실행
    /// - Parameters:
    ///   - loginId: 로그인 ID
    ///   - password: 평문 비밀번호 (TLS 구간 서버 해싱 위임)
    /// - Returns: 회원 ID + 토큰 쌍
    func execute(
        loginId: String,
        password: String
    ) async throws -> LoginByIdPwResult
}
