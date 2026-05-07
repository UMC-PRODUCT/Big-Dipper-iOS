//
//  RequestAttendanceRequestDTO.swift
//  AppProduct
//

import Foundation

/// GPS 출석 요청 DTO
///
/// `POST /api/v2/schedules/{scheduleId}/attendances/request`
///
/// - Note: excuse 엔드포인트의 `isVerified` 와 달리 이 엔드포인트는 `locationVerified` 를 사용합니다.
///   서버 스펙 그대로 필드명을 유지합니다.
struct RequestAttendanceRequestDTO: Encodable, Sendable {
    /// 위도
    let latitude: Double
    /// GPS 위치 인증 여부
    let locationVerified: Bool
    /// 경도
    let longitude: Double
}
