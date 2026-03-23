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
/// 출석 가능 일정 API를 통해 세션 목록을 제공합니다.
final class ActivityRepository: ActivityRepositoryProtocol, @unchecked Sendable {
    private struct SessionDetailPayload: Sendable {
        let schedule: AvailableAttendanceSchedule
        let detail: ScheduleDetailData
    }

    // MARK: - Property

    private let attendanceRepository: ChallengerAttendanceRepositoryProtocol
    private let homeRepository: HomeRepositoryProtocol

    // MARK: - Init

    init(
        attendanceRepository: ChallengerAttendanceRepositoryProtocol,
        homeRepository: HomeRepositoryProtocol
    ) {
        self.attendanceRepository = attendanceRepository
        self.homeRepository = homeRepository
    }

    // MARK: - Function

    @MainActor
    func fetchSessions() async throws -> [Session] {
        let schedules = try await attendanceRepository
            .getAvailableSchedules()

        let payloads = try await withThrowingTaskGroup(
            of: SessionDetailPayload.self
        ) { group in
            for schedule in schedules {
                group.addTask { [homeRepository] in
                    let detail = try await homeRepository.getScheduleDetail(
                        scheduleId: schedule.scheduleId
                    )
                    return SessionDetailPayload(
                        schedule: schedule,
                        detail: detail
                    )
                }
            }

            var payloads: [SessionDetailPayload] = []
            for try await payload in group {
                payloads.append(payload)
            }
            return payloads
        }

        return payloads
            .map(Self.makeSession(from:))
            .sorted { lhs, rhs in
                lhs.info.startTime < rhs.info.startTime
            }
    }

    func fetchCurrentUserId() async throws -> UserID {
        let memberId = UserDefaults.standard.integer(
            forKey: AppStorageKey.memberId
        )
        return UserID(value: String(memberId))
    }

    // MARK: - Private Helper

    /// 시간 문자열 → 오늘 날짜 기준 Date 변환
    ///
    /// 지원 형식: ISO 8601, "HH:mm:ss", "HH:mm"
    nonisolated private static func parseTime(_ timeString: String) -> Date {
        // 서버 UTC 시간(ISO 8601 또는 HH:mm:ss/HH:mm) 파싱
        ServerDateTimeConverter.parseUTCDateTimeOrTime(timeString) ?? Date()
    }

    private static func makeSession(
        from payload: SessionDetailPayload
    ) -> Session {
        let schedule = payload.schedule
        let detail = payload.detail
        let startTime = parseTime(schedule.startTime)
        var endTime = parseTime(schedule.endTime)

        // FIXME: 자정 넘김 휴리스틱 — 서버가 ISO 8601 datetime 반환 시 제거 (#304) - [25.02.18] 이재원
        if endTime < startTime {
            endTime = Calendar.current.date(
                byAdding: .day, value: 1, to: endTime
            ) ?? endTime
        }

        return Session(
            info: SessionInfo(
                sessionId: SessionID(
                    value: String(schedule.scheduleId)
                ),
                icon: .Activity.profile,
                title: schedule.scheduleName,
                week: 0,
                startTime: startTime,
                endTime: endTime,
                location: Coordinate(
                    latitude: detail.latitude,
                    longitude: detail.longitude
                ),
                isAllDay: detail.isAllDay
            ),
            initialAttendance: mapAttendance(
                schedule: schedule
            )
        )
    }

    /// AvailableAttendanceSchedule의 status → 초기 Attendance 변환
    nonisolated private static func mapAttendance(
        schedule: AvailableAttendanceSchedule
    ) -> Attendance? {
        switch schedule.status {
        case .beforeAttendance:
            return nil
        case .pendingApproval:
            return Attendance(
                sessionId: SessionID(
                    value: String(schedule.scheduleId)
                ),
                userId: UserID(value: ""),
                type: schedule.locationVerified ? .gps : .reason,
                status: .pendingApproval,
                locationVerification: nil,
                reason: nil
            )
        case .present, .late, .absent:
            return Attendance(
                sessionId: SessionID(
                    value: String(schedule.scheduleId)
                ),
                userId: UserID(value: ""),
                type: schedule.locationVerified ? .gps : .reason,
                status: schedule.status,
                locationVerification: nil,
                reason: nil
            )
        }
    }
}
