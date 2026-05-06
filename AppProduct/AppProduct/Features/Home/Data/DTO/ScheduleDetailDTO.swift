//
//  ScheduleDetailDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/13/26.
//

import Foundation

/// 일정 상세/목록 응답 DTO (V2)
///
/// V2 스키마에서는 목록(`GET /api/v2/schedules/me`)과 상세(`GET /api/v2/schedules/{id}`) 응답이
/// 동일한 형태로 내려오므로, 단일 DTO 로 양쪽을 모두 처리합니다.
///
/// 클라이언트가 사라진 V1 필드를 직접 계산하도록 도메인 모델에서 보강합니다.
/// - `isAllDay` 는 `(startsAt...endsAt).isAllDayInKST` 로 판정
/// - `dDay` 는 KST 기준 캘린더로 계산
///
/// - SeeAlso: ``ScheduleDetailData``
struct ScheduleDetailDTO: Codable, Sendable, Equatable {

    /// 일정 고유 식별자
    let scheduleId: Int
    /// 일정 제목
    let name: String
    /// 일정 설명 (메모)
    let description: String
    /// 카테고리 태그 목록
    let tags: [String]
    /// 시작 일시 (UTC ISO8601 문자열)
    let startsAt: String
    /// 종료 일시 (UTC ISO8601 문자열)
    let endsAt: String
    /// 장소 객체 (`nil` = 비대면)
    let location: V2LocationDTO?
    /// 참여자 풀 객체 배열
    let participants: [ScheduleParticipantDTO]
    /// 작성자 멤버 ID
    let authorMemberId: Int
    /// 출석 정책 객체 (`nil` = 출석 비필수)
    let attendancePolicy: V2AttendancePolicyDTO?
    /// 현재 사용자의 출석 상태 (서버 raw 문자열)
    let attendanceStatus: String?
    /// 출석 체크 완료 여부
    let isAttendanceChecked: Bool
    /// 비대면 일정 여부
    let isOnline: Bool
    /// 현재 사용자의 참여 여부
    let isParticipant: Bool

    private enum CodingKeys: String, CodingKey {
        case scheduleId
        case name
        case description
        case tags
        case startsAt
        case endsAt
        case location
        case participants
        case authorMemberId
        case attendancePolicy
        case attendanceStatus
        case isAttendanceChecked
        case isOnline
        case isParticipant
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheduleId = try container.decodeIntFlexibleIfPresent(forKey: .scheduleId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt) ?? ""
        endsAt = try container.decodeIfPresent(String.self, forKey: .endsAt) ?? ""
        location = try container.decodeIfPresent(V2LocationDTO.self, forKey: .location)
        participants = try container.decodeIfPresent([ScheduleParticipantDTO].self, forKey: .participants) ?? []
        authorMemberId = try container.decodeIntFlexibleIfPresent(forKey: .authorMemberId) ?? 0
        attendancePolicy = try container.decodeIfPresent(V2AttendancePolicyDTO.self, forKey: .attendancePolicy)
        attendanceStatus = try container.decodeIfPresent(String.self, forKey: .attendanceStatus)
        isAttendanceChecked = try container.decodeBoolFlexibleIfPresent(forKey: .isAttendanceChecked) ?? false
        isOnline = try container.decodeBoolFlexibleIfPresent(forKey: .isOnline) ?? false
        isParticipant = try container.decodeBoolFlexibleIfPresent(forKey: .isParticipant) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(tags, forKey: .tags)
        try container.encode(startsAt, forKey: .startsAt)
        try container.encode(endsAt, forKey: .endsAt)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(participants, forKey: .participants)
        try container.encode(authorMemberId, forKey: .authorMemberId)
        try container.encodeIfPresent(attendancePolicy, forKey: .attendancePolicy)
        try container.encodeIfPresent(attendanceStatus, forKey: .attendanceStatus)
        try container.encode(isAttendanceChecked, forKey: .isAttendanceChecked)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(isParticipant, forKey: .isParticipant)
    }
}

// MARK: - toDomain

extension ScheduleDetailDTO {

    /// DTO → ScheduleDetailData 변환
    func toScheduleDetailData() -> ScheduleDetailData {
        ScheduleDetailData(
            scheduleId: scheduleId,
            name: name,
            description: description,
            tags: tags,
            startsAt: Self.parseISO8601(startsAt),
            endsAt: Self.parseISO8601(endsAt),
            location: location?.toDomain(),
            participants: participants.map { $0.toDomain() },
            authorMemberId: authorMemberId,
            attendancePolicy: attendancePolicy?.toDomain(),
            attendanceStatus: attendanceStatus.map(AttendanceStatus.init(serverStatus:)),
            isAttendanceChecked: isAttendanceChecked,
            isOnline: isOnline,
            isParticipant: isParticipant
        )
    }

    private static func parseISO8601(_ string: String) -> Date {
        ServerDateTimeConverter.parseUTCDateTime(string) ?? .now
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

    func decodeBoolFlexibleIfPresent(forKey key: Key) throws -> Bool? {
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decode(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "1", "y", "yes":
                return true
            case "false", "0", "n", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
