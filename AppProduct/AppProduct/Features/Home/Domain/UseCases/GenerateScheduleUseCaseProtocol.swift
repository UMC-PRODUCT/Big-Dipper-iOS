//
//  GenerateScheduleUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

/// 일정 생성 UseCase Protocol
protocol GenerateScheduleUseCaseProtocol {
    /// 일정 생성
    /// - Parameter schedule: 일정 생성 요청 DTO
    /// - Returns: 생성된 일정 ID (V2 응답의 `result.scheduleId`)
    @discardableResult
    func execute(schedule: GenerateScheduleRequetDTO) async throws -> Int
}
