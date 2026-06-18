//
//  RegisterUseCaseProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

// MARK: - Protocol

/// 회원가입 UseCase Protocol
protocol RegisterUseCaseProtocol {
    /// 회원가입 실행
    ///
    /// 서버가 가입 응답에 토큰을 함께 내려주면 즉시 저장하여 별도 재로그인 없이
    /// 세션을 복구합니다.
    /// - Parameter request: 회원가입 요청 DTO
    /// - Returns: 회원 ID + (서버가 제공할 경우) 토큰 쌍
    func execute(request: RegisterRequestDTO) async throws -> RegisterResult
}
