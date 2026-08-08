//
//  ForceDeleteScheduleUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 강제 삭제 UseCase 인터페이스
///
/// 일반 삭제가 출석 기록을 이유로 거부됐을 때의 에스컬레이션 경로다.
public protocol ForceDeleteScheduleUseCaseProtocol {

    /// - Parameter scheduleId: 강제 삭제할 일정 식별자
    func execute(scheduleId: String) async throws
}
