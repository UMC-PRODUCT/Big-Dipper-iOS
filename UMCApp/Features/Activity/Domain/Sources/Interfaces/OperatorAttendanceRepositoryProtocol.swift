//
//  OperatorAttendanceRepositoryProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

// MARK: - Input Model

/// 출석 일괄 결정 요청 항목
public struct AttendanceDecisionInput: Equatable, Sendable {
    public let isApproved: Bool

    /// 결정 대상 참여자 멤버 ID (서버 응답)
    public let participantMemberId: String
    public let reason: String

    public init(isApproved: Bool, participantMemberId: String, reason: String) {
        self.isApproved = isApproved
        self.participantMemberId = participantMemberId
        self.reason = reason
    }
}

// MARK: - Protocol

/// 운영진 시점의 출석 관리 (조회 · 일괄 결정 · 위치 변경)
///
/// 챌린저 본인의 출석 요청은 ``ChallengerAttendanceRepositoryProtocol``.
public protocol OperatorAttendanceRepositoryProtocol {

    // MARK: - 조회

    /// 일정 출석 현황 목록 조회 (관리자)
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
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo]

    /// 단일 일정 출석 현황 조회 (관리자)
    ///
    /// `GET /api/v2/schedules/{scheduleId}/attendance` 호출.
    ///
    /// - Parameters:
    ///   - scheduleId: 일정 식별자
    ///   - attendanceStatus: 필터링할 출석 상태 (`nil` 이면 모든 상태)
    func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo

    // MARK: - 액션

    /// 출석 일괄 승인/반려
    func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult]

    /// 세션 출석 위치 변경 (관리자)
    func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws
}
