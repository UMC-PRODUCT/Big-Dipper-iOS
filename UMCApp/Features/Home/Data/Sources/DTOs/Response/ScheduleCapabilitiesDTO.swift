//
//  ScheduleCapabilitiesDTO.swift
//  HomeData
//
//  Created by euijjang97 on 8/9/26.
//

import Foundation
import HomeDomain
import UMCFoundation

/// `GET /api/v2/schedules/capabilities` 응답 DTO
///
/// - SeeAlso: ``HomeDomain/ScheduleCapabilities``
public struct ScheduleCapabilitiesDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 일정 생성 가능 여부
    public let canCreateSchedule: Bool

    /// 출석 정책을 포함한 일정을 만들 수 있는지 여부 (운영진 `true` / 일반 챌린저 `false`)
    public let canCreateAttendanceRequiredSchedule: Bool

    /// 직책별 최대 초대 가능 인원. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let maxParticipantCount: String

    private enum CodingKeys: String, CodingKey {
        case canCreateSchedule
        case canCreateAttendanceRequiredSchedule
        case maxParticipantCount
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canCreateSchedule = try container.decodeBoolFlexibleIfPresent(
            forKey: .canCreateSchedule
        ) ?? false
        canCreateAttendanceRequiredSchedule = try container.decodeBoolFlexibleIfPresent(
            forKey: .canCreateAttendanceRequiredSchedule
        ) ?? false
        // 숫자/문자열 어느 쪽으로 와도 같은 값이 되도록 숫자 파싱을 한 번 거친 뒤 문자열로 보존한다.
        let parsedMaxParticipantCount = try container.decodeIntFlexibleIfPresent(
            forKey: .maxParticipantCount
        )
        maxParticipantCount = parsedMaxParticipantCount.map { String($0) } ?? "0"
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canCreateSchedule, forKey: .canCreateSchedule)
        try container.encode(
            canCreateAttendanceRequiredSchedule,
            forKey: .canCreateAttendanceRequiredSchedule
        )
        try container.encode(maxParticipantCount, forKey: .maxParticipantCount)
    }
}

// MARK: - Domain 변환

extension ScheduleCapabilitiesDTO {

    /// DTO → 도메인 변환
    func toDomain() -> ScheduleCapabilities {
        ScheduleCapabilities(
            canCreateSchedule: canCreateSchedule,
            canCreateAttendanceRequiredSchedule: canCreateAttendanceRequiredSchedule,
            maxParticipantCount: maxParticipantCount
        )
    }
}
