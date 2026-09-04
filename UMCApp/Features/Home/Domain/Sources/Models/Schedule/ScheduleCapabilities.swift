//
//  ScheduleCapabilities.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/9/26.
//

import Foundation

/// 일정 생성/수정 권한 도메인 모델
///
/// 일정 생성/수정 화면에서 버튼 활성화 여부, 출석 정책 토글 노출 여부,
/// 참여자 선택 상한을 서버 주도로 결정할 때 사용한다.
public struct ScheduleCapabilities: Equatable, Sendable {

    // MARK: - Property

    /// 일정 생성 가능 여부
    public let canCreateSchedule: Bool

    /// 출석 정책을 포함한 일정을 만들 수 있는지 여부 (운영진 `true` / 일반 챌린저 `false`)
    public let canCreateAttendanceRequiredSchedule: Bool

    /// 직책별 최대 초대 가능 인원. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let maxParticipantCount: String

    // MARK: - Init

    public init(
        canCreateSchedule: Bool,
        canCreateAttendanceRequiredSchedule: Bool,
        maxParticipantCount: String
    ) {
        self.canCreateSchedule = canCreateSchedule
        self.canCreateAttendanceRequiredSchedule = canCreateAttendanceRequiredSchedule
        self.maxParticipantCount = maxParticipantCount
    }
}
