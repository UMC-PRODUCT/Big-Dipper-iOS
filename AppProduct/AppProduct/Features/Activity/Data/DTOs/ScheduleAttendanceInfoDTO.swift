//
//  ScheduleAttendanceInfoDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// V2 운영진 출석 현황 응답 DTO (목록/단일 공용)
///
/// - 목록 응답: `[ScheduleAttendanceInfoDTO]`
/// - 단일 응답: `ScheduleAttendanceInfoDTO`
///
/// 두 엔드포인트가 동일한 객체 스키마를 사용하므로 DTO 도 단일로 정의합니다.
///
/// - SeeAlso: ``ScheduleAttendanceInfo``
struct ScheduleAttendanceInfoDTO: Codable, Sendable, Equatable {

    /// 일정 식별자
    let scheduleId: Int

    /// 일정 제목
    let name: String

    /// 일정 설명
    let description: String

    /// 시작 일시 (UTC ISO8601)
    let startsAt: String

    /// 종료 일시 (UTC ISO8601)
    let endsAt: String

    /// 비대면 일정 여부
    let isOnline: Bool

    /// 장소 (`nil` = 비대면)
    let location: V2LocationDTO?

    /// 작성자 멤버 ID
    let authorMemberId: Int

    /// 출석 정책 (`nil` 가능)
    let attendancePolicy: V2AttendancePolicyDTO?

    /// 카테고리 태그
    let tags: [String]

    /// 참여자별 출석 정보
    let participants: [V2AttendanceParticipantDTO]

    private enum CodingKeys: String, CodingKey {
        case scheduleId
        case name
        case description
        case startsAt
        case endsAt
        case isOnline
        case location
        case authorMemberId
        case attendancePolicy
        case tags
        case participants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheduleId = try container.decodeIntFlexibleIfPresent(forKey: .scheduleId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt) ?? ""
        endsAt = try container.decodeIfPresent(String.self, forKey: .endsAt) ?? ""
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
        location = try container.decodeIfPresent(V2LocationDTO.self, forKey: .location)
        authorMemberId = try container.decodeIntFlexibleIfPresent(forKey: .authorMemberId) ?? 0
        attendancePolicy = try container.decodeIfPresent(V2AttendancePolicyDTO.self, forKey: .attendancePolicy)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        participants = try container.decodeIfPresent([V2AttendanceParticipantDTO].self, forKey: .participants) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(startsAt, forKey: .startsAt)
        try container.encode(endsAt, forKey: .endsAt)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(authorMemberId, forKey: .authorMemberId)
        try container.encodeIfPresent(attendancePolicy, forKey: .attendancePolicy)
        try container.encode(tags, forKey: .tags)
        try container.encode(participants, forKey: .participants)
    }
}

// MARK: - Domain Mapping

extension ScheduleAttendanceInfoDTO {

    /// DTO → 도메인 변환
    ///
    /// 일자 파싱 실패 시 ISO8601 빈 값(`.now`) 으로 폴백.
    func toDomain() -> ScheduleAttendanceInfo {
        ScheduleAttendanceInfo(
            scheduleId: scheduleId,
            name: name,
            description: description,
            startsAt: ServerDateTimeConverter.parseUTCDateTime(startsAt) ?? .now,
            endsAt: ServerDateTimeConverter.parseUTCDateTime(endsAt) ?? .now,
            location: location?.toDomain(),
            isOnline: isOnline,
            authorMemberId: authorMemberId,
            attendancePolicy: attendancePolicy?.toDomain(),
            tags: tags,
            participants: participants.map { $0.toDomain() }
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeIntFlexible(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let intValue = Int(value) {
            return intValue
        }
        if let value = try? decode(Double.self, forKey: key) {
            return Int(value)
        }
        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int/String-number/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeIntFlexible(forKey: key)
    }
}
