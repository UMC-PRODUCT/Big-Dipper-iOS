//
//  OperatorAttendancePreviewSupport.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import ActivityDomain
import Foundation
import HomeDomain
import UMCFoundation

// MARK: - Preview Stub UseCase

/// 네트워크 없이 운영진 출석 화면을 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
///
/// 결정(`decideAttendances`)은 로컬 상태를 바꾸지 않고 요청한 결정을 그대로 반영한 결과만
/// 돌려준다. 화면의 낙관적 갱신 경로를 그대로 태우기 위함이다.
final class PreviewOperatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol {

    // MARK: - Property

    private let schedules: [ScheduleAttendanceInfo]

    // MARK: - Init

    init(schedules: [ScheduleAttendanceInfo] = OperatorAttendancePreviewData.schedules) {
        self.schedules = schedules
    }

    // MARK: - Function

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo] {
        guard let attendanceStatus else { return schedules }
        return schedules.filter { schedule in
            schedule.participants.contains { $0.attendanceStatus == attendanceStatus }
        }
    }

    func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo {
        guard let matched = schedules.first(where: { $0.scheduleId == scheduleId }) else {
            throw ActivityPreviewError.notFound(scheduleId)
        }
        return matched
    }

    func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        decisions.map { decision in
            AttendanceDecisionResult(
                status: decision.isApproved ? .present : .absent,
                decidedAt: OperatorAttendancePreviewData.referenceDate,
                decisionReason: decision.reason,
                excuseReason: nil,
                latitude: nil,
                longitude: nil,
                decisionMakerMemberInfo: AttendanceDecisionResult.DecisionMakerInfo(
                    memberId: "1",
                    name: "김유엠",
                    nickname: "유엠",
                    schoolId: "3",
                    schoolName: "한성대학교"
                ),
                isPendingDecision: false
            )
        }
    }

    func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {}
}

// MARK: - Preview Data

/// 운영진 출석 화면 프리뷰 픽스처
///
/// 시간 의존 값은 `Date(timeIntervalSince1970:)` 기준으로 고정해 실행 시점과 무관하게
/// 같은 화면이 나오도록 한다.
enum OperatorAttendancePreviewData {

    /// 픽스처 기준 시각 (2026-08-03 19:00 KST)
    static let referenceDate = Date(timeIntervalSince1970: 1_785_492_000)

    static let schedules: [ScheduleAttendanceInfo] = [
        ScheduleAttendanceInfo(
            scheduleId: "801",
            name: "iOS 파트 정기 세미나",
            description: "주차별 커리큘럼 세미나입니다.",
            startsAt: referenceDate,
            endsAt: referenceDate.addingTimeInterval(7_200),
            location: ScheduleLocation(
                latitude: 37.582_573,
                longitude: 127.010_111,
                locationName: "한성대학교 상상관 5층"
            ),
            isOnline: false,
            authorMemberId: "1",
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: referenceDate.addingTimeInterval(-1_800),
                onTimeEndAt: referenceDate.addingTimeInterval(600),
                lateEndAt: referenceDate.addingTimeInterval(1_800)
            ),
            tags: ["세미나"],
            participants: [
                makeParticipant(id: "11", name: "김챌린", status: .presentPending),
                makeParticipant(id: "12", name: "박지각", status: .latePending),
                makeParticipant(
                    id: "13",
                    name: "이사유",
                    status: .excusedPending,
                    excuseReason: "학과 전공 필수 수업과 시간이 겹칩니다."
                ),
                makeParticipant(id: "14", name: "최출석", status: .present),
                makeParticipant(id: "15", name: "정결석", status: .absent),
            ]
        ),
        ScheduleAttendanceInfo(
            scheduleId: "802",
            name: "중앙 연합 워크숍",
            description: "전국 지부 합동 워크숍입니다.",
            startsAt: referenceDate.addingTimeInterval(604_800),
            endsAt: referenceDate.addingTimeInterval(612_000),
            location: nil,
            isOnline: true,
            authorMemberId: "1",
            attendancePolicy: nil,
            tags: ["워크숍", "온라인"],
            participants: [
                makeParticipant(id: "11", name: "김챌린", status: .present),
                makeParticipant(id: "12", name: "박지각", status: .late),
            ]
        ),
    ]

    // MARK: - Helper

    private static func makeParticipant(
        id: String,
        name: String,
        status: ParticipantAttendanceStatus,
        excuseReason: String? = nil
    ) -> ParticipantAttendance {
        ParticipantAttendance(
            memberId: id,
            name: name,
            nickname: "\(name)닉",
            profileImageURL: "",
            schoolId: "3",
            schoolName: "한성대학교",
            attendanceStatus: status,
            isLocationVerified: status == .present,
            excuseReason: excuseReason
        )
    }
}

// MARK: - Preview Error

/// 프리뷰 스텁이 요청 대상을 못 찾았을 때 던지는 에러
enum ActivityPreviewError: LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            "프리뷰 데이터에 없는 항목입니다: \(id)"
        }
    }
}
#endif
