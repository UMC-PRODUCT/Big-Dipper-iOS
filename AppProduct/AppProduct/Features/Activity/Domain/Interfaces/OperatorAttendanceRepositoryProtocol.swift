//
//  OperatorAttendanceRepositoryProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/17/26.
//

import Foundation

// MARK: - Input Model

/// 출석 일괄 결정 요청 항목 도메인 입력 모델
struct AttendanceDecisionInput: Equatable, Sendable {
    let isApproved: Bool
    let participantMemberId: Int
    let reason: String
}

// MARK: - Protocol

/// 운영진 출석 관리 데이터 접근 Repository
protocol OperatorAttendanceRepositoryProtocol {

    // MARK: - 조회

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

    /// 출석 일괄 승인/반려 (V2)
    func decideAttendances(
        scheduleId: Int,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult]

    /// 세션 출석 위치 변경 (관리자)
    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws
}
