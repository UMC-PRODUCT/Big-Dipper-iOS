//
//  ScheduleUpdateRequest.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 수정 입력 모델
///
/// `PATCH /api/v2/schedules/{id}` 로 보낼 값을 도메인 어휘로 표현한다. 부분 수정이므로 모든
/// 필드가 Optional 이고, `nil` 은 "변경하지 않음"을 뜻한다 (요청 본문에서 생략된다).
///
/// - Note: `participantMemberIds` 는 생성 입력과 마찬가지로 절대 규칙 #2 에 따라 `String` 으로
///   다루며, 서버 request 계약(`Set<Long>`)에 맞춘 `Int` 변환은 Data 레이어가 수행한다.
public struct ScheduleUpdateRequest: Equatable, Sendable {

    // MARK: - Property

    public let name: String?
    public let description: String?
    public let startsAt: Date?
    public let endsAt: Date?
    /// 장소 (`nil` = 변경 없음 — 비대면 전환은 `isOnline` 으로 표현한다)
    public let location: ScheduleLocation?
    /// 참여자 멤버 식별자 목록 (전체 교체)
    public let participantMemberIds: [String]?
    public let tags: [String]?
    /// 출석 정책 (`nil` = 변경 없음 — 출석 비필수 전환은 `isAttendanceRequired` 로 표현한다)
    public let attendancePolicy: ScheduleAttendancePolicy?
    /// 비대면 여부. `nil` = 변경 없음, `true`/`false` = 명시적 전환
    public let isOnline: Bool?
    /// 출석 필수 여부. `nil` = 변경 없음, `true`/`false` = 명시적 전환
    public let isAttendanceRequired: Bool?

    // MARK: - Init

    public init(
        name: String? = nil,
        description: String? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        location: ScheduleLocation? = nil,
        participantMemberIds: [String]? = nil,
        tags: [String]? = nil,
        attendancePolicy: ScheduleAttendancePolicy? = nil,
        isOnline: Bool? = nil,
        isAttendanceRequired: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
        self.participantMemberIds = participantMemberIds
        self.tags = tags
        self.attendancePolicy = attendancePolicy
        self.isOnline = isOnline
        self.isAttendanceRequired = isAttendanceRequired
    }
}
