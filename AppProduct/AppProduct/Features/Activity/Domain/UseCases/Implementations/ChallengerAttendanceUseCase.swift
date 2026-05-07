//
//  ChallengerAttendanceUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/9/26.
//

import Foundation

// MARK: - Implementation

final class ChallengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol {

    // MARK: - Property

    private let repository: ChallengerAttendanceRepositoryProtocol
    private let locationManager: LocationManager = .shared

    // MARK: - Computed Property

    var isInsideGeofence: Bool {
        locationManager.isInsideGeofence
    }

    var isLocationAuthorized: Bool {
        locationManager.isAuthorized
    }

    // MARK: - Init

    init(repository: ChallengerAttendanceRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 출석 가능한 세션 목록 조회
    ///
    /// 향후 ±2주 범위에서 출석 필수(`attendancePolicy != nil`) + 참여자인 일정을 반환합니다.
    /// 출석 창이 아직 열리지 않은 일정도 포함하여 View에서 `beforeAttendance` 상태로 표시할 수 있도록 합니다.
    func fetchAvailableSchedules() async throws -> [ScheduleDetailData] {
        let now = Date.now
        let to = Calendar.kstGregorian.date(byAdding: .day, value: 14, to: now) ?? now
        let schedules = try await repository.fetchMySchedulesForAttendance(from: now, to: to)
        return schedules.filter { $0.attendancePolicy != nil && $0.isParticipant }
    }

    /// 내 출석 이력 조회
    ///
    /// 6개월 이내 일정 중 출석 정책이 있는 과거 일정을 반환합니다.
    func fetchMyHistory() async throws -> [ScheduleDetailData] {
        let now = Date.now
        let sixMonthsAgo = Calendar.kstGregorian.date(
            byAdding: .month, value: -6, to: now
        ) ?? now
        let schedules = try await repository.fetchMySchedulesForAttendance(
            from: sixMonthsAgo,
            to: now
        )
        return schedules.filter { $0.attendancePolicy != nil }
    }

    /// GPS 기반 출석 요청 (V2)
    /// - throws: LocationError.notAuthorized, LocationError.locationFailed, DomainError.attendanceOutOfRange
    func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: Int
    ) async throws -> Attendance {
        guard locationManager.isAuthorized else {
            throw LocationError.notAuthorized
        }

        guard let coordinate = locationManager.currentCoordinate else {
            throw LocationError.locationFailed("현재 위치를 가져올 수 없습니다.")
        }

        guard locationManager.isInsideGeofence else {
            throw DomainError.attendanceOutOfRange
        }

        let result = try await repository.requestAttendance(
            scheduleId: scheduleId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locationVerified: true
        )

        return result.toAttendance(sessionId: sessionId, userId: userId)
    }

    /// 지각 사유 제출 (V2)
    /// - throws: DomainError.attendanceReasonRequired
    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: Int
    ) async throws -> Attendance {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.attendanceReasonRequired
        }

        let result = try await submitExcuse(
            sessionId: sessionId,
            userId: userId,
            reason: reason,
            scheduleId: scheduleId
        )
        return result
    }

    /// 불참 사유 제출 (V2)
    /// - throws: DomainError.attendanceReasonRequired
    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: Int
    ) async throws -> Attendance {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.attendanceReasonRequired
        }

        let result = try await submitExcuse(
            sessionId: sessionId,
            userId: userId,
            reason: reason,
            scheduleId: scheduleId
        )
        return result
    }

    /// 현재 시간이 어느 출석 시간대에 속하는지 확인
    func isWithinAttendanceTime(info: SessionInfo) -> AttendanceTimeWindow {
        let now = Date()
        let onTimeThreshold = TimeInterval(AttendanceGeofenceConstants.onTimeThresholdMinutes * 60)
        let lateThreshold = TimeInterval(AttendanceGeofenceConstants.lateThresholdMinutes * 60)
        let startTime = info.startTime

        if info.isAllDay {
            if now < startTime.addingTimeInterval(-onTimeThreshold) {
                return .tooEarly
            }
            if now <= info.endTime {
                return .onTime
            }
            return .expired
        } else {
            if now < startTime.addingTimeInterval(-onTimeThreshold) {
                return .tooEarly
            }

            if now <= startTime.addingTimeInterval(onTimeThreshold) {
                return .onTime
            }

            if now <= startTime.addingTimeInterval(lateThreshold) {
                return .lateWindow
            }

            return .expired
        }
    }

    /// 지오코딩
    func getAddressToCurrentLocation() async throws -> String {
        guard let coordinate = locationManager.currentCoordinate else {
            throw LocationError.locationFailed("주소를 찾을 수 없습니다.")
        }
        return try await locationManager.reverseGeocode(coordinate: coordinate)
    }

    /// 지오펜스 모니터링 중지
    func stopGeofenceMonitoring() async {
        await locationManager.stopAllGeofenceMonitoring()
    }

    // MARK: - Private

    private func submitExcuse(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: Int
    ) async throws -> Attendance {
        let coordinate = locationManager.currentCoordinate

        let result = try await repository.submitExcuse(
            scheduleId: scheduleId,
            excuseReason: reason,
            isVerified: coordinate != nil,
            latitude: coordinate?.latitude ?? 0.0,
            longitude: coordinate?.longitude ?? 0.0
        )
        return result.toAttendance(sessionId: sessionId, userId: userId)
    }
}
