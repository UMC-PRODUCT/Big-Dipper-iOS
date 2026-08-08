//
//  DeleteScheduleUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 삭제 UseCase 인터페이스
///
/// 출석 기록이 있는 일정은 서버가 거부하고 `DomainError.scheduleHasAttendanceRecords` 로
/// 전달되므로, 호출부는 그 신호를 받아 강제 삭제로 넘어갈지 결정한다.
public protocol DeleteScheduleUseCaseProtocol {

    /// - Parameter scheduleId: 삭제할 일정 식별자
    func execute(scheduleId: String) async throws
}
