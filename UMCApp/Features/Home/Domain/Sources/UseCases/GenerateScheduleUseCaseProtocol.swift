//
//  GenerateScheduleUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 생성 UseCase 인터페이스
public protocol GenerateScheduleUseCaseProtocol {

    /// - Parameter request: 일정 생성 입력 모델
    /// - Returns: 생성된 일정 식별자 (서버 정수를 절대 규칙 #2 에 따라 `String` 으로 보존)
    @discardableResult
    func execute(request: ScheduleCreationRequest) async throws -> String
}
