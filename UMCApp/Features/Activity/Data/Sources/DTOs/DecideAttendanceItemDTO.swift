//
//  DecideAttendanceItemDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/6/26.
//

import Foundation

/// 출석 일괄 승인/반려 요청 배열 항목 DTO
///
/// `POST /api/v2/schedules/{scheduleId}/attendances/decide` body array item.
/// 운영진이 다수 참여자의 출석을 한 번에 승인/반려할 때 각 결정을 표현합니다.
///
/// - Note: `participantMemberId` 는 서버가 모든 정수 ID를 문자열로 직렬화하므로
///   `String` 으로 유지합니다 (도메인의 `AttendanceDecisionInput.participantMemberId`
///   와 동일 타입). Int 변환은 필요한 연산 시점에만 수행합니다.
struct DecideAttendanceItemDTO: Encodable, Sendable {
    /// 승인 여부 (`false` 이면 반려)
    let isApproved: Bool
    /// 결정 대상 참여자 멤버 ID (서버 응답 — 전 레이어 `String` 통일)
    let participantMemberId: String
    /// 결정 사유 (빈 문자열 허용)
    let reason: String
}
