//
//  ExcuseAttendanceRequestDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/6/26.
//

import Foundation

/// 사유 출석 제출 요청 DTO
///
/// `POST /api/v2/schedules/{scheduleId}/attendances/excuse` body.
/// 지오펜스 밖 등으로 정시 출석이 불가능한 챌린저가 사유와 함께 출석을 제출할 때 사용합니다.
///
/// - Note: request 엔드포인트의 ``RequestAttendanceRequestDTO/locationVerified`` 와 달리
///   이 엔드포인트는 `isVerified` 라는 필드명을 사용합니다. 서버 스펙 그대로 필드명을
///   유지해야 하므로 두 DTO의 위치 인증 필드명이 다릅니다.
struct ExcuseAttendanceRequestDTO: Encodable, Sendable {
    /// 사유 내용 (빈 문자열은 서버에서 거부)
    let excuseReason: String
    /// GPS 위치 인증 여부 (request의 `locationVerified` 와 필드명이 다름)
    let isVerified: Bool
    /// 위도
    let latitude: Double
    /// 경도
    let longitude: Double
}
