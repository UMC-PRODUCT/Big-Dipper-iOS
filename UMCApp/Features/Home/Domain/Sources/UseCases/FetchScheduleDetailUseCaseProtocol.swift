//
//  FetchScheduleDetailUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/6/26.
//

import Foundation

/// 단일 일정 상세 조회 UseCase 인터페이스
public protocol FetchScheduleDetailUseCaseProtocol {

    /// - Parameter scheduleId: 조회할 일정 식별자
    /// - Returns: 목록과 동일 스키마의 일정 상세 모델
    func execute(scheduleId: String) async throws -> ScheduleDetailData
}
