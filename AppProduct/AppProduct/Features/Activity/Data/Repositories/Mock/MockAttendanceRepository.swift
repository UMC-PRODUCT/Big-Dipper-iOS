//
//  MockAttendanceRepository.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/15/26.
//

import Foundation

/// Preview 및 테스트용 Mock AttendanceRepository
///
/// 실제 네트워크 요청 없이 더미 데이터를 반환합니다.
final class MockAttendanceRepository: ChallengerAttendanceRepositoryProtocol,
                                       OperatorAttendanceRepositoryProtocol {

    // MARK: - 조회

    func getAttendanceDetail(
        recordId: Int
    ) async throws -> AttendanceRecord {
        AttendanceRecord(
            id: recordId,
            attendanceSheetId: 1,
            memberId: 1,
            status: .present,
            memo: nil
        )
    }

    func getPendingAttendances(
        scheduleId: Int
    ) async throws -> [PendingAttendanceRecord] {
        [
            PendingAttendanceRecord(
                attendanceId: 1,
                memberId: 1,
                memberName: "일일일",
                nickname: "길동이",
                profileImageLink: nil,
                schoolName: "중앙대학교",
                status: .pendingApproval,
                reason: "병원 방문으로 인한 지각",
                requestedAt: .now
            )
        ]
    }

    func getAllPendingAttendances(
    ) async throws -> [Int: [PendingAttendanceRecord]] {
        [
            1: [
                PendingAttendanceRecord(
                    attendanceId: 1,
                    memberId: 1,
                    memberName: "일일일",
                    nickname: "길동이",
                    profileImageLink: nil,
                    schoolName: "중앙대학교",
                    status: .pendingApproval,
                    reason: "병원 방문으로 인한 지각",
                    requestedAt: .now
                )
            ]
        ]
    }

    func getMyHistory() async throws -> [AttendanceHistoryItem] {
        [
            AttendanceHistoryItem(
                attendanceId: 1,
                scheduleId: 1,
                scheduleName: "9기 OT",
                tags: ["SEMINAR", "ALL"],
                scheduledDate: "2024-01-15",
                startTime: "14:30",
                endTime: "16:00",
                status: .present,
                statusDisplay: "출석"
            )
        ]
    }

    func getChallengerHistory(
        challengerId: Int
    ) async throws -> [AttendanceHistoryItem] {
        try await getMyHistory()
    }

    func getScheduleStats(
    ) async throws -> [ScheduleAttendanceStats] {
        [
            ScheduleAttendanceStats(
                scheduleId: 1,
                name: "9기 OT",
                date: "2026-03-17",
                startTime: "10:00:00",
                endTime: "12:00:00",
                locationName: "중앙대학교",
                totalCount: 40,
                presentCount: 34,
                pendingCount: 6,
                attendanceRate: 0.85
            )
        ]
    }

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo] {
        _ = from
        _ = to
        _ = attendanceStatus
        return [
            ScheduleAttendanceInfo(
                scheduleId: 1,
                name: "9기 OT",
                description: "오리엔테이션",
                startsAt: .now,
                endsAt: .now.addingTimeInterval(60 * 90),
                location: ScheduleLocation(
                    latitude: 37.50543,
                    longitude: 126.9569,
                    locationName: "중앙대학교 R&D센터"
                ),
                isOnline: false,
                authorMemberId: 1,
                attendancePolicy: nil,
                tags: ["LEADERSHIP"],
                participants: [
                    ParticipantAttendance(
                        memberId: 1,
                        name: "홍길동",
                        nickname: "길동이",
                        profileImageUrl: "",
                        schoolId: 1,
                        schoolName: "중앙대학교",
                        attendanceStatus: .presentPending,
                        isLocationVerified: true,
                        excuseReason: nil
                    )
                ]
            )
        ]
    }

    func fetchAttendanceDetail(
        scheduleId: Int,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> ScheduleAttendanceInfo {
        _ = attendanceStatus
        return ScheduleAttendanceInfo(
            scheduleId: scheduleId,
            name: "9기 OT",
            description: "오리엔테이션",
            startsAt: .now,
            endsAt: .now.addingTimeInterval(60 * 90),
            location: ScheduleLocation(
                latitude: 37.50543,
                longitude: 126.9569,
                locationName: "중앙대학교 R&D센터"
            ),
            isOnline: false,
            authorMemberId: 1,
            attendancePolicy: nil,
            tags: ["LEADERSHIP"],
            participants: [
                ParticipantAttendance(
                    memberId: 1,
                    name: "홍길동",
                    nickname: "길동이",
                    profileImageUrl: "",
                    schoolId: 1,
                    schoolName: "중앙대학교",
                    attendanceStatus: .present,
                    isLocationVerified: true,
                    excuseReason: nil
                )
            ]
        )
    }

    func getAvailableSchedules(
    ) async throws -> [AvailableAttendanceSchedule] {
        [
            AvailableAttendanceSchedule(
                scheduleId: 1,
                scheduleName: "9기 OT",
                tags: ["STUDY", "PROJECT"],
                startTime: "10:00:00",
                endTime: "12:00:00",
                sheetId: 1,
                recordId: 1,
                status: .beforeAttendance,
                statusDisplay: "출석 전",
                locationVerified: true
            )
        ]
    }

    // MARK: - 액션

    func approveAttendance(recordId: Int) async throws {}

    func rejectAttendance(recordId: Int) async throws {}

    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        _ = scheduleId
        _ = locationName
        _ = latitude
        _ = longitude
    }

    func checkAttendance(
        request: AttendanceCheckRequestDTO
    ) async throws -> Int {
        1
    }

    func submitReason(
        request: AttendanceReasonRequestDTO
    ) async throws -> Int {
        1
    }
}
