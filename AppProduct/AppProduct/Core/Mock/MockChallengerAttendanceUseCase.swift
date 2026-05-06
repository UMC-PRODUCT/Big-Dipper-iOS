//
//  MockChallengerAttendanceUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/15/26.
//

import Foundation

#if DEBUG
/// 테스트용 Mock UseCase
///
/// 실제 네트워크 요청 없이 출석 요청을 시뮬레이션합니다.
/// 승인/거절은 AttendanceTestWrapper의 관리자 패널에서 처리합니다.
@Observable
final class MockChallengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol {

    // MARK: - Configurable State

    /// 지오펜스 내부 여부 (테스트용)
    var mockIsInsideGeofence: Bool = true

    /// 위치 권한 여부 (테스트용)
    var mockIsLocationAuthorized: Bool = true

    /// 시뮬레이션할 시간대 (nil이면 실제 계산)
    var mockTimeWindow: AttendanceTimeWindow?

    /// 에러 시뮬레이션 (nil이면 성공)
    var mockError: Error?

    /// 응답 지연 시간 (초)
    var responseDelay: TimeInterval = 1.0

    // MARK: - Protocol Properties

    var isInsideGeofence: Bool { mockIsInsideGeofence }
    var isLocationAuthorized: Bool { mockIsLocationAuthorized }

    // MARK: - Protocol Methods

    func requestGPSAttendance(sessionId: SessionID, userId: UserID, sheetId: Int) async throws -> Attendance {
        try await Task.sleep(for: .seconds(responseDelay))

        if let error = mockError {
            throw error
        }

        return Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .gps,
            status: .beforeAttendance,
            locationVerification: .init(
                isVerified: true,
                coordinate: .init(latitude: 37.582967, longitude: 127.010527),
                address: .init(fullAddress: "한성대학교", city: "서울시", district: "성북구"),
                verifiedAt: .now
            ),
            reason: nil
        )
    }

    func submitLateReason(sessionId: SessionID, userId: UserID, reason: String, sheetId: Int) async throws -> Attendance {
        try await Task.sleep(for: .seconds(responseDelay))

        if let error = mockError {
            throw error
        }

        return Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .beforeAttendance,
            locationVerification: nil,
            reason: reason
        )
    }

    func submitAbsentReason(sessionId: SessionID, userId: UserID, reason: String, sheetId: Int) async throws -> Attendance {
        try await Task.sleep(for: .seconds(responseDelay))

        return Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .beforeAttendance,
            locationVerification: nil,
            reason: reason
        )
    }

    func fetchAvailableSchedules() async throws -> [AvailableAttendanceSchedule] {
        try await Task.sleep(for: .seconds(responseDelay))
        if let error = mockError { throw error }
        return []
    }

    func fetchMyHistory() async throws -> [AttendanceHistoryItem] {
        try await Task.sleep(for: .seconds(responseDelay))
        if let error = mockError { throw error }
        return []
    }

    func isWithinAttendanceTime(info: SessionInfo) -> AttendanceTimeWindow {
        if let mockWindow = mockTimeWindow {
            return mockWindow
        }

        let now = Date()
        let onTimeThreshold = TimeInterval(AttendanceGeofenceConstants.onTimeThresholdMinutes * 60)
        let lateThreshold = TimeInterval(AttendanceGeofenceConstants.lateThresholdMinutes * 60)
        let startTime = info.startTime

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

    func getAddressToCurrentLocation() async throws -> String {
        return "Mock 주소 - 서울시 성북구 한성대학교"
    }

    func stopGeofenceMonitoring() async {
        // Mock에서는 아무 작업도 하지 않음
    }
}
#endif
