//
//  UpdateScheduleRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/13/26.
//

import Foundation

/// 홈 일정 수정 Request DTO (V2)
///
/// `PATCH /api/v2/schedules/{id}` 의 요청 본문을 인코딩합니다.
/// PATCH 의미상 변경이 필요한 필드만 부분 전송할 수 있도록 모든 필드를 Optional 로 둡니다.
///
/// `isOnline` / `isAttendanceRequired` 는 3-state 플래그입니다:
/// - `nil`: 변경 없음 (필드 자체를 송신하지 않음)
/// - `true` / `false`: 명시적 전환
struct UpdateScheduleRequestDTO: Encodable {

    // MARK: - Property

    let name: String?
    let description: String?
    let startsAt: Date?
    let endsAt: Date?
    let location: V2LocationDTO?
    let participantMemberIds: [Int]?
    let tags: [ScheduleIconCategory]?
    let attendancePolicy: V2AttendancePolicyDTO?
    let isOnline: Bool?
    let isAttendanceRequired: Bool?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case name, description, startsAt, endsAt
        case location, participantMemberIds, tags, attendancePolicy
        case isOnline, isAttendanceRequired
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(participantMemberIds, forKey: .participantMemberIds)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(attendancePolicy, forKey: .attendancePolicy)
        try container.encodeIfPresent(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(isAttendanceRequired, forKey: .isAttendanceRequired)

        if let startsAt {
            try container.encode(
                ServerDateTimeConverter.toUTCDateTimeString(startsAt),
                forKey: .startsAt
            )
        }
        if let endsAt {
            try container.encode(
                ServerDateTimeConverter.toUTCDateTimeString(endsAt),
                forKey: .endsAt
            )
        }
    }
}
