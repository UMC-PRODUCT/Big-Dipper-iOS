//
//  ChallengerAttendanceUseCaseProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/9/26.
//

import Foundation

// MARK: - Protocol

protocol ChallengerAttendanceUseCaseProtocol {
    var isInsideGeofence: Bool { get }
    var isLocationAuthorized: Bool { get }

    /// 출석 가능한 세션 목록 조회
    func fetchAvailableSchedules() async throws -> [ScheduleDetailData]

    /// 내 출석 이력 조회
    func fetchMyHistory() async throws -> [ScheduleDetailData]

    /// GPS 기반 출석 요청 (V2)
    /// - throws: LocationError.notAuthorized, LocationError.locationFailed, DomainError.attendanceOutOfRange
    func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: Int
    ) async throws -> Attendance

    /// 지각 사유 제출 (V2)
    /// - throws: DomainError.attendanceReasonRequired
    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: Int
    ) async throws -> Attendance

    /// 불참 사유 제출 (V2)
    /// - throws: DomainError.attendanceReasonRequired
    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: Int
    ) async throws -> Attendance

    /// 현재 시간이 어느 출석 시간대에 속하는지 확인
    func isWithinAttendanceTime(info: SessionInfo) -> AttendanceTimeWindow

    /// 현재 위치 좌표 통한 지오코딩
    /// - throws: LocationArror.locationFailed
    func getAddressToCurrentLocation() async throws -> String

    /// 지오펜스 모니터링 중지
    func stopGeofenceMonitoring() async
}
