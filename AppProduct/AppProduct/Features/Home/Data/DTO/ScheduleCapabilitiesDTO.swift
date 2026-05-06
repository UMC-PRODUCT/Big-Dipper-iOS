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
