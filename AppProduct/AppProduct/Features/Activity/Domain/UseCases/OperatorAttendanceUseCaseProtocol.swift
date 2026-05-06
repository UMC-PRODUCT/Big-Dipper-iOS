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
    /// 개별 출석 승인
    func approveAttendance(recordId: Int) async throws
    /// 개별 출석 반려
    func rejectAttendance(recordId: Int) async throws

    /// 세션 출석 위치 변경
    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws

    /// 일정별 출석 통계 조회
    ///
    /// - Important: V1 엔드포인트 호출. V2 마이그레이션 완료 후 제거 예정.
    /// - SeeAlso: ``fetchAttendanceList(from:to:attendanceStatus:)``
    func fetchScheduleStats() async throws -> [ScheduleAttendanceStats]

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
