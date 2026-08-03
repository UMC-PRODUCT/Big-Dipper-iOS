//
//  ScheduleAttendanceInfo.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import HomeDomain

/// 운영진 시점의 일정 출석 현황
///
/// 한 일정에 참여한 멤버 전원의 출석 상태와 통계를 단일 값으로 표현합니다.
/// 목록·단일 조회 응답 스키마가 동일하므로 단일 모델로 합쳤습니다.
///
/// 장소·출석 정책은 `HomeDomain` 의 canonical 일정 모델을 그대로 사용합니다
/// (Activity 에 같은 모양의 타입을 다시 두지 않습니다).
///
/// - SeeAlso: ``ParticipantAttendance``, ``ParticipantAttendanceStatus``
public struct ScheduleAttendanceInfo: Equatable, Sendable, Identifiable {

    /// 일정 식별자 (서버 응답)
    public let scheduleId: String

    /// 일정 제목
    public let name: String

    /// 일정 설명 (메모)
    public let description: String

    /// 시작 일시
    public let startsAt: Date

    /// 종료 일시
    public let endsAt: Date

    /// 장소 (`nil` = 비대면)
    public let location: ScheduleLocation?

    /// 비대면 일정 여부 (정상 상태에서는 `location == nil` 과 동치)
    public let isOnline: Bool

    /// 작성자 멤버 ID (서버 응답)
    public let authorMemberId: String

    /// 출석 정책 (`nil` = 정책 미부착)
    public let attendancePolicy: ScheduleAttendancePolicy?

    /// 카테고리 태그 (e.g., `"LEADERSHIP"`)
    public let tags: [String]

    /// 참여자별 출석 정보
    public let participants: [ParticipantAttendance]

    public var id: String { scheduleId }

    public init(
        scheduleId: String,
        name: String,
        description: String,
        startsAt: Date,
        endsAt: Date,
        location: ScheduleLocation?,
        isOnline: Bool,
        authorMemberId: String,
        attendancePolicy: ScheduleAttendancePolicy?,
        tags: [String],
        participants: [ParticipantAttendance]
    ) {
        self.scheduleId = scheduleId
        self.name = name
        self.description = description
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
        self.isOnline = isOnline
        self.authorMemberId = authorMemberId
        self.attendancePolicy = attendancePolicy
        self.tags = tags
        self.participants = participants
    }

    // MARK: - Helpers

    /// 출석으로 인정되는 인원 수 (사유 결석·지각 포함)
    public var presentCount: Int {
        participants.filter {
            switch $0.attendanceStatus {
            case .present, .excused, .late:
                return true
            default:
                return false
            }
        }.count
    }

    /// 승인 대기 인원 카운트
    public var pendingCount: Int {
        participants.filter(\.attendanceStatus.isPending).count
    }

    /// 전체 참여자 수
    public var totalCount: Int { participants.count }

    /// 출석률 (0.0 - 1.0)
    public var attendanceRate: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(presentCount) / Double(totalCount)
    }

    /// 일정이 진행 중인지 (`startsAt...endsAt` 경계 포함)
    ///
    /// 목록·상세 폴링 트리거가 같은 판정을 공유하도록 모델에 둡니다.
    public func isOngoing(at now: Date = Date()) -> Bool {
        now >= startsAt && now <= endsAt
    }
}
