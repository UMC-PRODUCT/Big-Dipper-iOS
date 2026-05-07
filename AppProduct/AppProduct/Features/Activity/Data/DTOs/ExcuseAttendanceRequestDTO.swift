//
//  ExcuseAttendanceRequestDTO.swift
//  AppProduct
//

import Foundation

/// 사유 출석 제출 요청 DTO
///
/// `POST /api/v2/schedules/{scheduleId}/attendances/excuse`
struct ExcuseAttendanceRequestDTO: Encodable, Sendable {
    /// 사유 내용 (빈 문자열 거부 — SCHEDULE-0016)
    let excuseReason: String
    /// GPS 위치 인증 여부
    let isVerified: Bool
    /// 위도
    let latitude: Double
    /// 경도
    let longitude: Double
}
