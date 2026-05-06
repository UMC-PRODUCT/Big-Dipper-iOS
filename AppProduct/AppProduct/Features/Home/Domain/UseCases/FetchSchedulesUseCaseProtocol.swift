//
//  FetchSchedulesUseCaseProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

/// 기간 내 내 일정 조회 UseCase Protocol
protocol FetchSchedulesUseCaseProtocol {

    /// 기간 내 일정 조회 (V2)
    ///
    /// - Parameters:
    ///   - from: 조회 시작 시각 (UTC ISO8601 송신)
    ///   - to: 조회 종료 시각 (UTC ISO8601 송신)
    ///   - isAttendanceRequired: 출석 필수 일정만 조회할지 여부
    /// - Returns: KST 자정 기준 날짜별로 그룹핑된 일정 딕셔너리
    func execute(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]]
}
