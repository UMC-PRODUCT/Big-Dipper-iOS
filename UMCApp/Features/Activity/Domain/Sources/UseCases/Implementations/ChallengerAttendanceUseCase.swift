//
//  ChallengerAttendanceUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/20/26.
//

import Foundation
import UMCFoundation

/// `ChallengerAttendanceUseCaseProtocol` 의 기본 구현체
///
/// - 위치/지오펜스 의존은 `LocationProviding` Protocol 로 주입.
/// - Repository 는 `Int` 기반 `scheduleId` 를 받지만, UseCase 시그니처는 `String` 으로 통일.
///   (서버 ID 는 String 으로 직렬화되므로 모듈 경계에서만 변환)
public final class ChallengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol {

    // MARK: - Property

    private let repository: ChallengerAttendanceRepositoryProtocol
    private let locationProvider: LocationProviding

    // MARK: - Computed Property

    /// UI 상태 표시용 fallback — 추적 중인 지오펜스 중 어느 하나라도 안에 있는지.
    /// 특정 출석 가드는 `requestGPSAttendance` 내부의 `isInside(geofenceId:)` 식별자 기반 판정 사용.
    public var isInsideGeofence: Bool {
        locationProvider.isInsideAnyGeofence
    }

    public var isLocationAuthorized: Bool {
        locationProvider.isAuthorized
    }

    // MARK: - Init

    public init(
        repository: ChallengerAttendanceRepositoryProtocol,
        locationProvider: LocationProviding
    ) {
        self.repository = repository
        self.locationProvider = locationProvider
    }

    // MARK: - 출석 액션

    /// GPS 기반 출석 요청
    public func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: String
    ) async throws -> Attendance {
        guard locationProvider.isAuthorized else {
            throw LocationError.notAuthorized
        }

        guard let coordinate = locationProvider.currentCoordinate else {
            throw LocationError.locationFailed("현재 위치를 가져올 수 없습니다.")
        }

        guard locationProvider.isInside(geofenceId: scheduleId) else {
            throw DomainError.attendanceOutOfRange
        }

        let intScheduleId = try Self.toIntScheduleId(scheduleId)

        let result = try await repository.requestAttendance(
            scheduleId: intScheduleId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locationVerified: true
        )

        return result.toAttendance(sessionId: sessionId, userId: userId)
    }

    /// 지각 사유 제출
    public func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        try await submitExcuse(
            sessionId: sessionId,
            userId: userId,
            reason: reason,
            scheduleId: scheduleId
        )
    }

    /// 불참 사유 제출
    public func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        try await submitExcuse(
            sessionId: sessionId,
            userId: userId,
            reason: reason,
            scheduleId: scheduleId
        )
    }

    // MARK: - 시간 윈도우

    /// 기준 시각(`now`)이 어느 출석 시간대에 속하는지 판정
    public func isWithinAttendanceTime(
        info: SessionInfo,
        now: Date
    ) -> AttendanceTimeWindow {
        let onTimeThreshold = TimeInterval(
            AttendancePolicy.onTimeThresholdMinutes * 60
        )
        let lateThreshold = TimeInterval(
            AttendancePolicy.lateThresholdMinutes * 60
        )
        let startTime = info.startTime

        if info.isAllDay {
            if now < startTime.addingTimeInterval(-onTimeThreshold) {
                return .tooEarly
            }
            if now <= info.endTime {
                return .onTime
            }
            return .expired
        }

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

    // MARK: - 위치/지오펜스

    /// 현재 좌표 → 주소(도메인 모델) 역지오코딩
    public func getAddressToCurrentLocation() async throws -> Address {
        guard let coordinate = locationProvider.currentCoordinate else {
            throw LocationError.locationFailed("주소를 찾을 수 없습니다.")
        }
        return try await locationProvider.reverseGeocode(coordinate: coordinate)
    }

    /// 등록된 모든 지오펜스 모니터링 중지
    public func stopGeofenceMonitoring() async {
        await locationProvider.stopAllGeofenceMonitoring()
    }

    // MARK: - Private

    /// 사유 결석/지각 공통 제출
    ///
    /// 좌표 미보유 시 `isVerified = false` 로 보고 (lat/lng 0.0 폴백)
    private func submitExcuse(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.attendanceReasonRequired
        }

        let intScheduleId = try Self.toIntScheduleId(scheduleId)
        let coordinate = locationProvider.currentCoordinate

        let result = try await repository.submitExcuse(
            scheduleId: intScheduleId,
            excuseReason: reason,
            isVerified: coordinate != nil,
            latitude: coordinate?.latitude ?? 0.0,
            longitude: coordinate?.longitude ?? 0.0
        )
        return result.toAttendance(sessionId: sessionId, userId: userId)
    }

    /// 서버 String 식별자 → Repository Int 시그니처 변환
    ///
    /// 본 모듈 경계에서만 일어나는 변환 — UseCase 외부(ViewModel/Repository)는
    /// 서버용 String 식별자로 통일을 유지합니다.
    private static func toIntScheduleId(_ scheduleId: String) throws -> Int {
        guard let intValue = Int(scheduleId) else {
            throw DomainError.invalidScheduleId(scheduleId)
        }
        return intValue
    }
}
