//
//  ScheduleUpdateRequestDTO.swift
//  HomeData
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation
import HomeDomain
import UMCFoundation

/// 일정 수정 Request DTO (V2)
///
/// `PATCH /api/v2/schedules/{id}` 의 요청 본문을 인코딩한다. PATCH 의미상 값이 없는 필드는
/// `encodeIfPresent` 로 본문에서 통째로 빠지므로, 서버는 해당 필드를 기존 값으로 유지한다.
///
/// - Note: 서버 request 계약이 참여자 식별자를 `Set<Long>` 으로 받으므로 생성 요청과 동일하게
///   `participantMemberIds` 만 `Int` 로 직렬화한다 (핵심 규칙 #2 는 응답 한정).
struct ScheduleUpdateRequestDTO: Encodable, Sendable, Equatable {

    // MARK: - Property

    let name: String?
    let description: String?
    /// 시작 일시 (UTC ISO8601 문자열로 인코딩)
    let startsAt: Date?
    /// 종료 일시 (UTC ISO8601 문자열로 인코딩)
    let endsAt: Date?
    let location: ScheduleLocationRequestDTO?
    let participantMemberIds: [Int]?
    let tags: [String]?
    let attendancePolicy: ScheduleAttendancePolicyRequestDTO?
    /// 비대면 여부. `nil` 이면 필드를 보내지 않아 서버가 현행 유지하고,
    /// `true`/`false` 는 대면 ↔ 비대면 전환을 명시한다.
    let isOnline: Bool?
    /// 출석 필수 여부. `nil` 이면 필드를 보내지 않아 서버가 현행 유지하고,
    /// `true`/`false` 는 출석 필수 ↔ 비필수 전환을 명시한다.
    let isAttendanceRequired: Bool?

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case startsAt
        case endsAt
        case location
        case participantMemberIds
        case tags
        case attendancePolicy
        case isOnline
        case isAttendanceRequired
    }

    // MARK: - Function

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(
            startsAt.map(ServerDateTimeConverter.toUTCDateTimeString),
            forKey: .startsAt
        )
        try container.encodeIfPresent(
            endsAt.map(ServerDateTimeConverter.toUTCDateTimeString),
            forKey: .endsAt
        )
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(participantMemberIds, forKey: .participantMemberIds)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(attendancePolicy, forKey: .attendancePolicy)
        try container.encodeIfPresent(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(isAttendanceRequired, forKey: .isAttendanceRequired)
    }
}

// MARK: - Domain → DTO

extension ScheduleUpdateRequestDTO {

    /// 도메인 입력 모델을 요청 DTO 로 옮긴다.
    ///
    /// 참여자 식별자 중 정수로 해석되지 않는 값은 서버가 받을 수 없으므로 제외한다.
    init(domain: ScheduleUpdateRequest) {
        self.init(
            name: domain.name,
            description: domain.description,
            startsAt: domain.startsAt,
            endsAt: domain.endsAt,
            location: domain.location.map {
                ScheduleLocationRequestDTO(
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    locationName: $0.locationName
                )
            },
            participantMemberIds: domain.participantMemberIds?.compactMap(Int.init),
            tags: domain.tags,
            attendancePolicy: domain.attendancePolicy.map {
                ScheduleAttendancePolicyRequestDTO(
                    checkInStartAt: ServerDateTimeConverter.toUTCDateTimeString($0.checkInStartAt),
                    onTimeEndAt: ServerDateTimeConverter.toUTCDateTimeString($0.onTimeEndAt),
                    lateEndAt: ServerDateTimeConverter.toUTCDateTimeString($0.lateEndAt)
                )
            },
            isOnline: domain.isOnline,
            isAttendanceRequired: domain.isAttendanceRequired
        )
    }
}
