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
    func fetchAvailableSchedules() async throws -> [AvailableAttendanceSchedule] {
        return try await repository.getAvailableSchedules()
    }

    /// 내 출석 이력 조회
    func fetchMyHistory() async throws -> [AttendanceHistoryItem] {
        return try await repository.getMyHistory()
    }

    /// GPS 기반 출석 요청 (pending 상태로 서버 전송)
    /// - throws: LocationError.notAuthorized, LocationError.locationFailed, DomainError.attendanceOutOfRange
    func requestGPSAttendance(sessionId: SessionID, userId: UserID, sheetId: Int) async throws -> Attendance {
        // 위치 권한 검증
        guard locationManager.isAuthorized else {
            throw LocationError.notAuthorized
        }

        // 현재 위치 조회
        guard let coordinate = locationManager.currentCoordinate else {
            throw LocationError.locationFailed("현재 위치를 가져올 수 없습니다.")
        }

        // 지오펜싱 검증
        guard locationManager.isInsideGeofence else {
            throw DomainError.attendanceOutOfRange
        }

        // 서버에 GPS 출석 요청
        _ = try await repository.checkAttendance(
            request: AttendanceCheckRequestDTO(
                attendanceSheetId: sheetId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                locationVerified: true
            )
        )

        return Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .gps,
            status: .beforeAttendance,
            locationVerification: LocationVerification(
                isVerified: true,
                coordinate: coordinate,
                address: .init(
                    fullAddress: "",
                    city: "",
                    district: ""
                ),
                verifiedAt: .now
            ),
            reason: nil
        )
    }

    /// 지각 사유 제출
    /// - throws: DomainError.attendanceReasonRequired
    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        sheetId: Int
    ) async throws -> Attendance {
        // 사유 필수 검증
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.attendanceReasonRequired
        }

        // 서버에 지각 사유 제출
        _ = try await repository.submitReason(
            request: AttendanceReasonRequestDTO(
                attendanceSheetId: sheetId,
                reason: reason
            )
        )

        return Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .pendingApproval,
            locationVerification: nil,
            reason: reason
        )
    }

    /// 불참 사유 제출
    /// - throws: DomainError.attendanceReasonRequired
    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        sheetId: Int
    ) async throws -> Attendance {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.attendanceReasonRequired
        }

        _ = try await repository.submitReason(
            request: AttendanceReasonRequestDTO(
                attendanceSheetId: sheetId,
                reason: reason
            )
        )

        return Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .pendingApproval,
            locationVerification: nil,
            reason: reason
        )
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
            // 세션 시작 - threshold 이전이면 너무 이름
            if now < startTime.addingTimeInterval(-onTimeThreshold) {
                return .tooEarly
            }

            // 세션 시작 ± threshold 내이면 정시 출석 가능
            if now <= startTime.addingTimeInterval(onTimeThreshold) {
                return .onTime
            }

            // 세션 시작 + lateThreshold 내이면 지각 시간대
            if now <= startTime.addingTimeInterval(lateThreshold) {
                return .lateWindow
            }

            // 그 이후는 마감
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
}
