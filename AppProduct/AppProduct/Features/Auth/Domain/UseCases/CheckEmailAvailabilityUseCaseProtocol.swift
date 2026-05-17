//
//  CheckEmailAvailabilityUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

// MARK: - Protocol

/// 이메일 중복 검사 UseCase Protocol
protocol CheckEmailAvailabilityUseCaseProtocol {
    /// 이메일 중복 여부 확인
    /// - Parameter email: 검사 대상 이메일 주소
    /// - Returns: 사용 가능 여부 (true = 사용 가능)
    func execute(email: String) async throws -> Bool
}
