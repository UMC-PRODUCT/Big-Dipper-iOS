//
//  V2AttendancePolicyDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// V2 일정 API 의 `attendancePolicy` 객체 DTO
///
/// 운영진이 출석 필수 일정을 생성/수정할 때 함께 전송되며,
/// 응답에서도 일정에 출석 정책이 부착되어 있으면 동일한 형태로 내려옵니다.
/// 응답이 `null` 인 경우 출석 비필수 일정을 의미합니다.
///
/// - SeeAlso: ``AttendancePolicy``
struct V2AttendancePolicyDTO: Codable, Sendable, Equatable {

    /// 출석 체크인 시작 시각 (UTC ISO8601)
    let checkInStartAt: String

    /// 정시 출석 종료 시각 (UTC ISO8601)
    let onTimeEndAt: String

    /// 지각 종료 시각 (UTC ISO8601)
    let lateEndAt: String
}

// MARK: - Domain Mapping

extension V2AttendancePolicyDTO {

    /// DTO → 도메인 변환
    ///
    /// 어느 한 필드라도 ISO8601 파싱에 실패하면 `nil` 을 반환합니다.
    func toDomain() -> AttendancePolicy? {
        guard
            let checkIn = ServerDateTimeConverter.parseUTCDateTime(checkInStartAt),
            let onTime = ServerDateTimeConverter.parseUTCDateTime(onTimeEndAt),
            let late = ServerDateTimeConverter.parseUTCDateTime(lateEndAt)
        else {
            return nil
        }
        return AttendancePolicy(
            checkInStartAt: checkIn,
            onTimeEndAt: onTime,
            lateEndAt: late
        )
    }

    /// 도메인 → DTO 변환 (UTC ISO8601 직렬화)
    init(domain: AttendancePolicy) {
        self.checkInStartAt = ServerDateTimeConverter.toUTCDateTimeString(domain.checkInStartAt)
        self.onTimeEndAt = ServerDateTimeConverter.toUTCDateTimeString(domain.onTimeEndAt)
        self.lateEndAt = ServerDateTimeConverter.toUTCDateTimeString(domain.lateEndAt)
    }
}
