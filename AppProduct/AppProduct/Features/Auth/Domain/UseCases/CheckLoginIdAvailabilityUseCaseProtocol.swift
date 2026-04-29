//
//  CheckLoginIdAvailabilityUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

// MARK: - Protocol

/// 로그인 ID 중복 검사 UseCase Protocol
protocol CheckLoginIdAvailabilityUseCaseProtocol {
    /// 로그인 ID 중복 여부 확인
    /// - Parameter loginId: 검사 대상 로그인 ID
    /// - Returns: 사용 가능 여부 (true = 사용 가능)
    func execute(loginId: String) async throws -> Bool
}
