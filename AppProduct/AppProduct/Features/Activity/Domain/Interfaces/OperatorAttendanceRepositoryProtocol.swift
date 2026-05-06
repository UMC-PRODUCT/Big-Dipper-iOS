//
//  OperatorAttendanceRepositoryProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/17/26.
//

import Foundation

// MARK: - Protocol

/// 운영진 출석 관리 데이터 접근 Repository
protocol OperatorAttendanceRepositoryProtocol {

    // MARK: - 조회

    /// 승인 대기 출석 목록 조회 (관리자)
    func getPendingAttendances(
        scheduleId: Int
    ) async throws -> [PendingAttendanceRecord]

    /// 전체 승인 대기 출석 목록 일괄 조회 (관리자)
    /// - Returns: scheduleId별로 그룹핑된 Dictionary
    func getAllPendingAttendances() async throws -> [Int: [PendingAttendanceRecord]]

    /// 챌린저 출석 이력 조회
    func getChallengerHistory(
        challengerId: Int
    ) async throws -> [AttendanceHistoryItem]

    /// 일정별 출석 통계 조회 (관리자)
    ///
    /// - Important: V1 엔드포인트(`GET /api/v1/schedules`) 호출. V2 마이그레이션 완료 후 제거 예정.
    /// - SeeAlso: ``fetchAttendanceList(from:to:attendanceStatus:)`` (V2)
    func getScheduleStats() async throws -> [ScheduleAttendanceStats]

    /// 일정 출석 현황 목록 조회 (V2, 관리자)
    ///
    /// `GET /api/v2/schedules/attendance` 호출. 직책별 조회 범위는 서버에서 자동 분기.
    ///
    /// - Parameters:
    ///   - from: 조회 시작 시각 (`nil` 이면 서버 기본값 = 요청 시점 -1개월)
    ///   - to: 조회 종료 시각 (`nil` 이면 서버 기본값 = 요청 시점 +24시간)
    ///   - attendanceStatus: 필터링할 출석 상태 (`nil` 이면 모든 상태)
    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo]

    /// 단일 일정 출석 현황 조회 (V2, 관리자)
    ///
    /// `GET /api/v2/schedules/{scheduleId}/attendance` 호출.
    ///
    /// - Parameters:
    ///   - scheduleId: 일정 식별자
    ///   - attendanceStatus: 필터링할 출석 상태 (`nil` 이면 모든 상태)
    func fetchAttendanceDetail(
        scheduleId: Int,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> ScheduleAttendanceInfo

    // MARK: - 액션

    /// 출석 승인 (관리자)
    func approveAttendance(recordId: Int) async throws

    /// 출석 반려 (관리자)
    func rejectAttendance(recordId: Int) async throws

    /// 세션 출석 위치 변경 (관리자)
    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws
}
