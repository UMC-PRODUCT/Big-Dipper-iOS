//
//  ScheduleCapabilitiesDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// `GET /api/v2/schedules/capabilities` 응답 DTO
///
/// 일정 생성/수정 화면 진입 전, 사용자의 권한과 최대 초대 가능 인원을 조회합니다.
///
/// - SeeAlso: ``ScheduleCapabilities``
struct ScheduleCapabilitiesDTO: Codable {

    /// 일정 생성 가능 여부
    let canCreateSchedule: Bool

    /// 출석 정책 포함 일정 생성 가능 여부 (운영진 true / 일반 챌린저 false)
    let canCreateAttendanceRequiredSchedule: Bool

    /// 직책별 최대 초대 가능 인원
    let maxParticipantCount: Int

    private enum CodingKeys: String, CodingKey {
        case canCreateSchedule
        case canCreateAttendanceRequiredSchedule
        case maxParticipantCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canCreateSchedule = try container.decodeIfPresent(Bool.self, forKey: .canCreateSchedule) ?? false
        canCreateAttendanceRequiredSchedule = try container.decodeIfPresent(Bool.self, forKey: .canCreateAttendanceRequiredSchedule) ?? false
        maxParticipantCount = try container.decodeIntFlexibleIfPresent(forKey: .maxParticipantCount) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canCreateSchedule, forKey: .canCreateSchedule)
        try container.encode(canCreateAttendanceRequiredSchedule, forKey: .canCreateAttendanceRequiredSchedule)
        try container.encode(maxParticipantCount, forKey: .maxParticipantCount)
    }
}

// MARK: - Domain Mapping

extension ScheduleCapabilitiesDTO {

    /// DTO 를 도메인 모델로 변환합니다.
    func toDomain() -> ScheduleCapabilities {
        ScheduleCapabilities(
            canCreateSchedule: canCreateSchedule,
            canCreateAttendanceRequiredSchedule: canCreateAttendanceRequiredSchedule,
            maxParticipantCount: maxParticipantCount
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
