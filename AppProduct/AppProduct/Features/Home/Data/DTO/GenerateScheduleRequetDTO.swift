//
//  GenerateScheduleDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/11/26.
//

import Foundation

/// 홈 일정 생성 Request DTO (V2)
///
/// `POST /api/v2/schedules` 의 요청 본문을 인코딩합니다.
/// V1 의 `isAllDay` / `gisuId` / `requiresApproval` / 평탄 좌표 필드는 제거되었으며,
/// `location` 객체(`null` = 비대면) 와 `attendancePolicy` 객체로 재구성되었습니다.
struct GenerateScheduleRequetDTO: Encodable {

    // MARK: - Property

    let name: String
    let description: String
    let startsAt: Date
    let endsAt: Date
    /// `nil` 이면 비대면 일정으로 전송
    let location: V2LocationDTO?
    let participantMemberIds: [Int]
    let tags: [ScheduleIconCategory]
    /// 운영진이 출석 필수 일정을 생성할 때만 비-`nil`
    let attendancePolicy: V2AttendancePolicyDTO?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case name, description, startsAt, endsAt
        case location, participantMemberIds, tags, attendancePolicy
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(participantMemberIds, forKey: .participantMemberIds)
        try container.encode(tags, forKey: .tags)
        try container.encode(
            ServerDateTimeConverter.toUTCDateTimeString(startsAt),
            forKey: .startsAt
        )
        try container.encode(
            ServerDateTimeConverter.toUTCDateTimeString(endsAt),
            forKey: .endsAt
        )
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(attendancePolicy, forKey: .attendancePolicy)
    }
}
