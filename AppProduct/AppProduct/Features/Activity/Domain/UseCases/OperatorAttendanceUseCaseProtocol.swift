//
//  OperatorAttendanceUseCaseProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/9/26.
//

import Foundation

// MARK: - Protocol

protocol OperatorAttendanceUseCaseProtocol {
    /// 승인 대기 멤버 목록 조회
    func fetchPendingAttendances(scheduleId: Int) async throws -> [PendingAttendanceRecord]
    /// 전체 승인 대기 멤버 일괄 조회
    /// - Returns: scheduleId별로 그룹핑된 Dictionary
    func fetchAllPendingAttendances() async throws -> [Int: [PendingAttendanceRecord]]

    /// 출석 일괄 승인/반려 (V2)
    func decideAttendances(
        scheduleId: Int,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult]

    /// 세션 출석 위치 변경
    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws

    /// 운영진용 일정 출석 현황 목록 조회 (V2)
    ///
    /// 직책별 조회 범위는 서버에서 자동 분기됩니다.
    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo]

    /// 단일 일정 출석 현황 조회 (V2)
    func fetchAttendanceDetail(
        scheduleId: Int,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> ScheduleAttendanceInfo
}
