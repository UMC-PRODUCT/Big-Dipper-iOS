//
//  ScheduleDetailData.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/11/26.
//

import Foundation
import UMCFoundation

/// 홈 일정 캘린더가 표시하는 일정 상세 모델.
///
/// 서버 V2 스키마는 목록/상세 응답이 동일한 형태이므로 단일 모델로 양쪽을 지원한다.
/// 슬라이스 2(#914)에서 캘린더 표시에 필요한 필드로 시작해, #980에서 장소/참여자/출석 정책까지
/// 확장을 마쳤다.
public struct ScheduleDetailData: Equatable, Identifiable, Sendable {

    // MARK: - Property

    public var id: String { scheduleId }

    public let scheduleId: String
    public let name: String
    public let description: String
    public let tags: [String]
    public let startsAt: Date
    public let endsAt: Date
    public let isParticipant: Bool
    /// 일정 장소 (`nil` = 비대면)
    public let location: ScheduleLocation?
    public let participants: [ScheduleParticipant]
    /// 작성자 멤버 식별자. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let authorMemberId: String
    /// 출석 정책 (`nil` = 출석 비필수)
    public let attendancePolicy: ScheduleAttendancePolicy?
    /// 현재 사용자의 출석 상태 (서버가 내려주지 않으면 `nil`)
    public let attendanceStatus: ScheduleAttendanceStatus?
    public let isAttendanceChecked: Bool
    public let isOnline: Bool

    // MARK: - Init

    public init(
        scheduleId: String,
        name: String,
        description: String,
        tags: [String],
        startsAt: Date,
        endsAt: Date,
        isParticipant: Bool,
        location: ScheduleLocation? = nil,
        participants: [ScheduleParticipant] = [],
        authorMemberId: String = "",
        attendancePolicy: ScheduleAttendancePolicy? = nil,
        attendanceStatus: ScheduleAttendanceStatus? = nil,
        isAttendanceChecked: Bool = false,
        isOnline: Bool = false
    ) {
        self.scheduleId = scheduleId
        self.name = name
        self.description = description
        self.tags = tags
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isParticipant = isParticipant
        self.location = location
        self.participants = participants
        self.authorMemberId = authorMemberId
        self.attendancePolicy = attendancePolicy
        self.attendanceStatus = attendanceStatus
        self.isAttendanceChecked = isAttendanceChecked
        self.isOnline = isOnline
    }

    // MARK: - Computed

    /// 종일 일정 여부 — `(start...end)` 가 KST 기준 단일 일자 전체를 덮는지 판정한다.
    public var isAllDay: Bool {
        guard startsAt <= endsAt else { return false }
        return (startsAt...endsAt).isAllDayInKST
    }

    /// 출석 정책이 부착된 일정인지 여부.
    public var requiresAttendanceApproval: Bool {
        attendancePolicy != nil
    }

    /// 출석 표시가 의미를 갖는 마지막 시각.
    ///
    /// 정책이 있으면 지각 인정 마감(`lateEndAt`)과 일정 종료 중 늦은 쪽, 없으면 일정 종료 시각이다.
    /// 이 시각이 지나면 출석 가능 목록에서 제외한다.
    public var attendanceWindowEndsAt: Date {
        guard let attendancePolicy else { return endsAt }
        return max(attendancePolicy.lateEndAt, endsAt)
    }

    /// 참여자 멤버 식별자 목록.
    public var participantMemberIds: [String] {
        participants.map(\.memberId)
    }

    /// KST 기준 오늘 자정과 일정 시작 자정의 일수 차. 양수는 미래, 음수는 과거, 0은 오늘.
    public var dDay: Int {
        let calendar = Calendar.kstGregorian
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: startsAt)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    /// `dDay` 부호 규칙에 맞춘 화면 표시용 문자열 (미래: `D-N`, 과거: `D+N`, 오늘: `D-Day`).
    public var dDayText: String {
        if dDay > 0 {
            return "D-\(dDay)"
        }
        if dDay < 0 {
            return "D+\(abs(dDay))"
        }
        return "D-Day"
    }

    /// 종료/참여 여부 기반 표시 텍스트. 종료된 일정이면 `"종료됨"`, 그 외에는 참여 여부를 표시한다.
    public var participationStatusText: String {
        if Date() > endsAt {
            return "종료됨"
        }
        return isParticipant ? "참여 예정" : "참여 안 함"
    }
}
