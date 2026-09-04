//
//  ScheduleDetailDTO.swift
//  HomeData
//
//  Created by euijjang97 on 7/11/26.
//

import Foundation
import HomeDomain
import UMCFoundation

/// 일정 목록/상세 응답 DTO (V2)
///
/// `GET /api/v2/schedules/me` 목록과 `GET /api/v2/schedules/{id}` 상세 응답이 동일한
/// 형태로 내려오므로 단일 DTO로 처리한다. 슬라이스 2(#914)에서 캘린더 표시에 필요한 필드로
/// 시작해, #980에서 장소/참여자/출석 정책까지 확장을 마쳤다.
///
/// - SeeAlso: ``ScheduleDetailData``
public struct ScheduleDetailDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 일정 고유 식별자. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let scheduleId: String
    public let name: String
    public let description: String
    public let tags: [String]
    /// 시작 일시 (UTC ISO8601 문자열). 파싱은 호출부(Repository)에서 수행한다.
    public let startsAt: String
    /// 종료 일시 (UTC ISO8601 문자열)
    public let endsAt: String
    /// 현재 사용자의 참여 여부
    public let isParticipant: Bool
    /// 장소 객체 (`nil` = 비대면)
    public let location: ScheduleLocationDTO?
    public let participants: [ScheduleParticipantDTO]
    /// 작성자 멤버 식별자. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let authorMemberId: String
    /// 출석 정책 객체 (`nil` = 출석 비필수)
    public let attendancePolicy: ScheduleAttendancePolicyDTO?
    /// 현재 사용자의 출석 상태 (서버 raw 문자열). 도메인 변환 시 enum 으로 매핑한다.
    public let attendanceStatus: String?
    public let isAttendanceChecked: Bool
    /// 비대면 일정 여부
    public let isOnline: Bool

    private enum CodingKeys: String, CodingKey {
        case scheduleId
        case name
        case description
        case tags
        case startsAt
        case endsAt
        case isParticipant
        case location
        case participants
        case authorMemberId
        case attendancePolicy
        case attendanceStatus
        case isAttendanceChecked
        case isOnline
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheduleId = try container.decodeFlexibleString(forKey: .scheduleId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt) ?? ""
        endsAt = try container.decodeIfPresent(String.self, forKey: .endsAt) ?? ""
        isParticipant = try container.decodeBoolFlexibleIfPresent(forKey: .isParticipant) ?? false
        location = try container.decodeIfPresent(ScheduleLocationDTO.self, forKey: .location)
        participants = try container.decodeIfPresent(
            [ScheduleParticipantDTO].self, forKey: .participants
        ) ?? []
        authorMemberId = container.decodeFlexibleStringOrEmpty(forKey: .authorMemberId)
        attendancePolicy = try container.decodeIfPresent(
            ScheduleAttendancePolicyDTO.self, forKey: .attendancePolicy
        )
        attendanceStatus = try container.decodeIfPresent(String.self, forKey: .attendanceStatus)
        isAttendanceChecked = try container.decodeBoolFlexibleIfPresent(
            forKey: .isAttendanceChecked
        ) ?? false
        isOnline = try container.decodeBoolFlexibleIfPresent(forKey: .isOnline) ?? false
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(tags, forKey: .tags)
        try container.encode(startsAt, forKey: .startsAt)
        try container.encode(endsAt, forKey: .endsAt)
        try container.encode(isParticipant, forKey: .isParticipant)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(participants, forKey: .participants)
        try container.encode(authorMemberId, forKey: .authorMemberId)
        try container.encodeIfPresent(attendancePolicy, forKey: .attendancePolicy)
        try container.encodeIfPresent(attendanceStatus, forKey: .attendanceStatus)
        try container.encode(isAttendanceChecked, forKey: .isAttendanceChecked)
        try container.encode(isOnline, forKey: .isOnline)
    }
}

// MARK: - Domain 변환

extension ScheduleDetailDTO {

    /// DTO → `ScheduleDetailData` 변환. 날짜 파싱 실패 시 현재 시각으로 폴백한다.
    func toDomain() -> ScheduleDetailData {
        ScheduleDetailData(
            scheduleId: scheduleId,
            name: name,
            description: description,
            tags: tags,
            startsAt: ServerDateTimeConverter.parseUTCDateTime(startsAt) ?? .now,
            endsAt: ServerDateTimeConverter.parseUTCDateTime(endsAt) ?? .now,
            isParticipant: isParticipant,
            location: location?.toDomain(),
            participants: participants.map { $0.toDomain() },
            authorMemberId: authorMemberId,
            attendancePolicy: attendancePolicy?.toDomain(),
            attendanceStatus: attendanceStatus.map(ScheduleAttendanceStatus.init(serverStatus:)),
            isAttendanceChecked: isAttendanceChecked,
            isOnline: isOnline
        )
    }
}
