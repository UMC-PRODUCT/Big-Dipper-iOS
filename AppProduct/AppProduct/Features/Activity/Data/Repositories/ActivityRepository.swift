//
//  ActivityRepository.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/17/26.
//

import Foundation
import SwiftUI

/// Activity Repository 실제 구현체
///
/// V2 `GET /api/v2/schedules/me` 를 통해 출석 필수 일정을 조회하여 세션 목록을 제공합니다.
final class ActivityRepository: ActivityRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let attendanceRepository: ChallengerAttendanceRepositoryProtocol

    // MARK: - Init

    init(attendanceRepository: ChallengerAttendanceRepositoryProtocol) {
        self.attendanceRepository = attendanceRepository
    }

    // MARK: - Function

    @MainActor
    func fetchSessions() async throws -> [Session] {
        let now = Date.now
        let to = Calendar.kstGregorian.date(byAdding: .day, value: 14, to: now) ?? now
        let schedules = try await attendanceRepository
            .fetchMySchedulesForAttendance(from: now, to: to)

        return schedules
            .filter { $0.isParticipant }
            .map(Self.makeSession(from:))
            .sorted { $0.info.startTime < $1.info.startTime }
    }

    func fetchCurrentUserId() async throws -> UserID {
        let memberId = AppStorageKey.legacyMemberIdInt()
        return UserID(value: String(memberId))
    }

    // MARK: - Private Helper

    private static func makeSession(from data: ScheduleDetailData) -> Session {
        Session(
            info: SessionInfo(
                sessionId: SessionID(value: String(data.scheduleId)),
                icon: .Activity.profile,
                title: data.name,
                week: 0,
                startTime: data.startsAt,
                endTime: data.endsAt,
                location: Coordinate(
                    latitude: data.location?.latitude ?? 0,
                    longitude: data.location?.longitude ?? 0
                ),
                isAllDay: data.isAllDay
            ),
            initialAttendance: mapAttendance(from: data)
        )
    }

    nonisolated private static func mapAttendance(
        from data: ScheduleDetailData
    ) -> Attendance? {
        let status = data.attendanceStatus ?? .beforeAttendance
        switch status {
        case .beforeAttendance:
            return nil
        case .pendingApproval:
            return Attendance(
                sessionId: SessionID(value: String(data.scheduleId)),
                userId: UserID(value: ""),
                type: data.isAttendanceChecked ? .gps : .reason,
                status: .pendingApproval,
                locationVerification: nil,
                reason: nil
            )
        case .present, .late, .absent:
            return Attendance(
                sessionId: SessionID(value: String(data.scheduleId)),
                userId: UserID(value: ""),
                type: data.isAttendanceChecked ? .gps : .reason,
                status: status,
                locationVerification: nil,
                reason: nil
            )
        }
    }
}
