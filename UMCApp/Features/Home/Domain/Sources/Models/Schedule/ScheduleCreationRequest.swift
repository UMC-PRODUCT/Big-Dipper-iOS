//
//  ScheduleCreationRequest.swift
//  HomeDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation

/// 일정 생성 입력 모델
///
/// `POST /api/v2/schedules` 로 보낼 값을 도메인 어휘로 표현한다. 장소·출석 정책은 조회 쪽과
/// 같은 모델을 재사용하므로 생성 전용 사본을 두지 않는다.
///
/// - Note: `participantMemberIds` 는 서버 응답 식별자와 같은 값이라 핵심 규칙 #2 에 따라
///   `String` 으로 다룬다. 서버 request 계약은 정수(`Set<Long>`)이므로 `Int` 변환은 Data
///   레이어가 요청 DTO 를 만들 때 한 번만 수행한다.
public struct ScheduleCreationRequest: Equatable, Sendable {

    // MARK: - Property

    public let name: String
    public let description: String
    public let startsAt: Date
    public let endsAt: Date
    /// 일정 장소 (`nil` = 비대면)
    public let location: ScheduleLocation?
    /// 참여자 멤버 식별자 목록
    public let participantMemberIds: [String]
    /// 일정 태그 (예: `["STUDY"]`)
    public let tags: [String]
    /// 출석 정책 (`nil` = 출석 비필수)
    public let attendancePolicy: ScheduleAttendancePolicy?

    // MARK: - Init

    public init(
        name: String,
        description: String = "",
        startsAt: Date,
        endsAt: Date,
        location: ScheduleLocation? = nil,
        participantMemberIds: [String] = [],
        tags: [String],
        attendancePolicy: ScheduleAttendancePolicy? = nil
    ) {
        self.name = name
        self.description = description
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
        self.participantMemberIds = participantMemberIds
        self.tags = tags
        self.attendancePolicy = attendancePolicy
    }
}
