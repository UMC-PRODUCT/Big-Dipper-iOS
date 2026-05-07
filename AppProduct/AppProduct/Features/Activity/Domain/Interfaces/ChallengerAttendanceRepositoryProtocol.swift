//
//  ChallengerAttendanceRepositoryProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/17/26.
//

import Foundation

// MARK: - Protocol

/// 챌린저 출석 데이터 접근 Repository
protocol ChallengerAttendanceRepositoryProtocol {

    // MARK: - 조회

    /// 기간 내 내 일정 목록 조회 (V2, 출석 필수 필터 적용 가능)
    ///
    /// `GET /api/v2/schedules/me?isAttendanceRequired=true`
    func fetchMySchedulesForAttendance(
        from: Date,
        to: Date
    ) async throws -> [ScheduleDetailData]

    // MARK: - 액션

    /// GPS 출석 요청 (V2)
    func requestAttendance(
        scheduleId: Int,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult

    /// 사유 출석 제출 (V2)
    func submitExcuse(
        scheduleId: Int,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult
}
