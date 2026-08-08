//
//  UpdateScheduleUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 부분 수정 UseCase 인터페이스
public protocol UpdateScheduleUseCaseProtocol {

    /// - Parameters:
    ///   - scheduleId: 수정할 일정 식별자
    ///   - request: 값이 설정된 필드만 서버로 전송되는 부분 수정 입력
    func execute(scheduleId: String, request: ScheduleUpdateRequest) async throws
}
