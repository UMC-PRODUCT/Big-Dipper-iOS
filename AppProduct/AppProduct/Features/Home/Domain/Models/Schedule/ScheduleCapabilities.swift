//
//  ScheduleCapabilities.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 일정 생성/수정 권한 도메인 모델
///
/// `GET /api/v2/schedules/capabilities` 응답을 도메인으로 변환한 값입니다.
/// 일정 생성/수정 화면에서 버튼 활성화 여부, 출석 정책 토글 노출 여부, 참여자 선택 상한 등을 결정할 때 사용합니다.
///
/// - SeeAlso: ``ScheduleCapabilitiesDTO``, ``FetchScheduleCapabilitiesUseCaseProtocol``
struct ScheduleCapabilities: Equatable, Sendable {

    /// 일정 생성 가능 여부
    let canCreateSchedule: Bool

    /// 출석 정책 포함 일정 생성 가능 여부 (운영진 true / 일반 챌린저 false)
    let canCreateAttendanceRequiredSchedule: Bool

    /// 직책별 최대 초대 가능 인원
    let maxParticipantCount: Int
}
