//
//  LoginByEmailUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

// MARK: - Protocol

/// 이메일 로그인 UseCase Protocol
protocol LoginByEmailUseCaseProtocol {
    /// 이메일 로그인 실행
    /// - Parameters:
    ///   - email: 이메일 주소
    ///   - password: 평문 비밀번호 (TLS 구간 서버 해싱 위임)
    /// - Returns: 회원 ID + 토큰 쌍
    func execute(
        email: String,
        password: String
    ) async throws -> LoginByIdPwResult
}
