//
//  StubAttendanceRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/4/26.
//

#if DEBUG
import ActivityDomain
import Foundation

/// stub 세션에서 출석 화면을 서버 없이 표시하는 Repository.
///
/// 조회(목록/상세)는 픽스처를 반환한다. 챌린저 본인의 출석 액션과 운영진의 결정·위치
/// 변경은 실제 요청으로 넘어가지 않도록 미지원 에러를 던진다.
struct StubAttendanceRepository: ChallengerAttendanceRepositoryProtocol,
                                  OperatorAttendanceRepositoryProtocol {

    // MARK: - 조회 (운영진)

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo] {
        let schedules = StubSessionFixtures.attendanceSchedules()
        guard let attendanceStatus else { return schedules }
        return schedules.filter { schedule in
            schedule.participants.contains { $0.attendanceStatus == attendanceStatus }
        }
    }

    func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo {
        guard
            let info = StubSessionFixtures.attendanceSchedules()
                .first(where: { $0.scheduleId == scheduleId })
        else {
            throw StubSessionError.unsupported(action: "일정 출석 현황 조회")
        }
        return info
    }

    // MARK: - 액션 (운영진)

    func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        throw StubSessionError.unsupported(action: "출석 승인/반려")
    }

    func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        throw StubSessionError.unsupported(action: "출석 위치 변경")
    }

    // MARK: - 액션 (챌린저)

    func requestAttendance(
        scheduleId: String,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult {
        throw StubSessionError.unsupported(action: "GPS 출석 요청")
    }

    func submitExcuse(
        scheduleId: String,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult {
        throw StubSessionError.unsupported(action: "사유 결석/지각 제출")
    }
}
#endif
