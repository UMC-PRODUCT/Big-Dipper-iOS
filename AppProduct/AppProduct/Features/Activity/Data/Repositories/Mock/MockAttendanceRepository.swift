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

    func fetchMySchedulesForAttendance(
        from: Date,
        to: Date
    ) async throws -> [ScheduleDetailData] {
        _ = from
        _ = to
        return []
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

    // MARK: - 액션

    func decideAttendances(
        scheduleId: Int,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        decisions.map { _ in
            AttendanceDecisionResult(
                status: .present,
                decidedAt: .now,
                decisionReason: nil,
                excuseReason: nil,
                latitude: nil,
                longitude: nil,
                decisionMakerMemberInfo: nil,
                hasDecisionMakerMember: false,
                isPendingDecision: false
            )
        }
    }

    func requestAttendance(
        scheduleId: Int,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult {
        AttendanceDecisionResult(
            status: .presentPending,
            decidedAt: nil,
            decisionReason: nil,
            excuseReason: nil,
            latitude: latitude,
            longitude: longitude,
            decisionMakerMemberInfo: nil,
            hasDecisionMakerMember: false,
            isPendingDecision: true
        )
    }

    func submitExcuse(
        scheduleId: Int,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult {
        AttendanceDecisionResult(
            status: .excusedPending,
            decidedAt: nil,
            decisionReason: nil,
            excuseReason: excuseReason,
            latitude: latitude,
            longitude: longitude,
            decisionMakerMemberInfo: nil,
            hasDecisionMakerMember: false,
            isPendingDecision: true
        )
    }

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
}
