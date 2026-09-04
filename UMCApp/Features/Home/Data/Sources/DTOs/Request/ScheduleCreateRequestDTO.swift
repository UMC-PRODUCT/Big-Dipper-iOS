//
//  ScheduleCreateRequestDTO.swift
//  HomeData
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import HomeDomain
import UMCFoundation

/// 일정 생성 Request DTO (V2)
///
/// `POST /api/v2/schedules` 의 요청 본문을 인코딩한다.
///
/// - Note: 서버 request 계약(`CreateScheduleRequest`)이 참여자 식별자를 `Set<Long>` 으로
///   받으므로 `participantMemberIds` 는 `Int` 로 직렬화한다. 응답의 정수를 `String` 으로
///   다루는 규칙(핵심 규칙 #2)은 응답 한정이며, 요청 본문에는 적용하지 않는다.
struct ScheduleCreateRequestDTO: Encodable, Sendable, Equatable {

    // MARK: - Property

    let name: String
    let description: String
    /// 시작 일시 (UTC ISO8601 문자열로 인코딩)
    let startsAt: Date
    /// 종료 일시 (UTC ISO8601 문자열로 인코딩)
    let endsAt: Date
    /// `nil` 이면 비대면 일정으로 전송
    let location: ScheduleLocationRequestDTO?
    let participantMemberIds: [Int]
    let tags: [String]
    /// 출석 필수 일정을 만들 때만 비-`nil`
    let attendancePolicy: ScheduleAttendancePolicyRequestDTO?

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case startsAt
        case endsAt
        case location
        case participantMemberIds
        case tags
        case attendancePolicy
    }

    // MARK: - Function

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(
            ServerDateTimeConverter.toUTCDateTimeString(startsAt),
            forKey: .startsAt
        )
        try container.encode(
            ServerDateTimeConverter.toUTCDateTimeString(endsAt),
            forKey: .endsAt
        )
        try container.encode(participantMemberIds, forKey: .participantMemberIds)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(attendancePolicy, forKey: .attendancePolicy)
    }
}

// MARK: - 중첩 객체

/// 생성 요청의 `location` 객체
struct ScheduleLocationRequestDTO: Encodable, Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let locationName: String
}

/// 생성 요청의 `attendancePolicy` 객체
///
/// 세 시각 모두 UTC ISO8601 문자열로 보낸다.
struct ScheduleAttendancePolicyRequestDTO: Encodable, Sendable, Equatable {
    let checkInStartAt: String
    let onTimeEndAt: String
    let lateEndAt: String
}

// MARK: - Domain → DTO

extension ScheduleCreateRequestDTO {

    /// 도메인 입력 모델을 요청 DTO 로 옮긴다.
    ///
    /// 참여자 식별자 중 정수로 해석되지 않는 값은 서버가 받을 수 없으므로 제외한다.
    /// (정상 경로에서는 서버가 준 정수 문자열이라 항상 변환된다.)
    init(domain: ScheduleCreationRequest) {
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
            participantMemberIds: domain.participantMemberIds.compactMap(Int.init),
            tags: domain.tags,
            attendancePolicy: domain.attendancePolicy.map {
                ScheduleAttendancePolicyRequestDTO(
                    checkInStartAt: ServerDateTimeConverter.toUTCDateTimeString($0.checkInStartAt),
                    onTimeEndAt: ServerDateTimeConverter.toUTCDateTimeString($0.onTimeEndAt),
                    lateEndAt: ServerDateTimeConverter.toUTCDateTimeString($0.lateEndAt)
                )
            }
        )
    }
}
