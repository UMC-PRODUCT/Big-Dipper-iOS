//
//  ScheduleAttendancePolicyDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/10/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

/// 출석 현황 응답의 `attendancePolicy` 객체 DTO
///
/// 일정에 부착된 동적 출석 시각 임계값(체크인 시작 · 정시 종료 · 지각 종료). 응답이
/// `null` 이면 출석 비필수 일정을 의미하므로 상위 DTO 에서 옵셔널로 보유합니다.
///
/// - SeeAlso: ``ActivityDomain/ScheduleAttendancePolicy``
struct ScheduleAttendancePolicyDTO: Codable, Sendable, Equatable {

    /// 출석 체크인 시작 시각 (UTC ISO8601)
    let checkInStartAt: String

    /// 정시 출석 종료 시각 (UTC ISO8601)
    let onTimeEndAt: String

    /// 지각 종료 시각 (UTC ISO8601)
    let lateEndAt: String

    private enum CodingKeys: String, CodingKey {
        case checkInStartAt
        case onTimeEndAt
        case lateEndAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checkInStartAt = try container.decodeIfPresent(String.self, forKey: .checkInStartAt) ?? ""
        onTimeEndAt = try container.decodeIfPresent(String.self, forKey: .onTimeEndAt) ?? ""
        lateEndAt = try container.decodeIfPresent(String.self, forKey: .lateEndAt) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(checkInStartAt, forKey: .checkInStartAt)
        try container.encode(onTimeEndAt, forKey: .onTimeEndAt)
        try container.encode(lateEndAt, forKey: .lateEndAt)
    }
}

// MARK: - Domain Mapping

extension ScheduleAttendancePolicyDTO {

    /// DTO → 도메인 변환
    ///
    /// 세 시각 중 하나라도 UTC ISO8601 파싱에 실패하면 정책 자체가 무의미하므로 `nil`.
    /// 상위 DTO 는 이 `nil` 을 "정책 미부착(출석 비필수)" 과 동일하게 취급합니다.
    func toDomain() -> ScheduleAttendancePolicy? {
        guard
            let checkIn = ServerDateTimeConverter.parseUTCDateTime(checkInStartAt),
            let onTime = ServerDateTimeConverter.parseUTCDateTime(onTimeEndAt),
            let late = ServerDateTimeConverter.parseUTCDateTime(lateEndAt)
        else {
            return nil
        }
        return ScheduleAttendancePolicy(
            checkInStartAt: checkIn,
            onTimeEndAt: onTime,
            lateEndAt: late
        )
    }
}
