//
//  RequestAttendanceRequestDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/6/26.
//

import Foundation

/// GPS 출석 요청 DTO
///
/// `POST /api/v2/schedules/{scheduleId}/attendances/request` body.
/// 챌린저 본인이 현재 위치 기반으로 출석을 체크할 때 사용합니다.
///
/// - Note: excuse 엔드포인트의 ``ExcuseAttendanceRequestDTO/isVerified`` 와 달리
///   이 엔드포인트는 `locationVerified` 라는 필드명을 사용합니다. 서버 스펙 그대로
///   필드명을 유지해야 하므로 두 DTO의 위치 인증 필드명이 다릅니다.
struct RequestAttendanceRequestDTO: Encodable, Sendable {
    /// 위도
    let latitude: Double
    /// GPS 위치 인증 여부 (excuse의 `isVerified` 와 필드명이 다름)
    let locationVerified: Bool
    /// 경도
    let longitude: Double
}
