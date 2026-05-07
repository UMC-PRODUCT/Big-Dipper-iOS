//
//  DecideAttendanceItemDTO.swift
//  AppProduct
//

import Foundation

/// 출석 일괄 승인/반려 요청 배열 항목 DTO
///
/// `POST /api/v2/schedules/{scheduleId}/attendances/decide` body array item.
struct DecideAttendanceItemDTO: Encodable, Sendable {
    /// 승인 여부
    let isApproved: Bool
    /// 처리 대상 참여자 멤버 ID
    let participantMemberId: Int
    /// 결정 사유 (빈 문자열 허용)
    let reason: String
}
