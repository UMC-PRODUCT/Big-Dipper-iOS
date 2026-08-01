//
//  ScheduleAttendanceStatus.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 일정에 대한 현재 사용자의 출석 상태
///
/// 표시용 텍스트/색상 매핑은 Presentation 레이어의 책임이므로 도메인에는 두지 않는다.
///
/// > Note: Home → Activity 모듈 의존을 만들지 않기 위해 `ActivityDomain/AttendanceStatus` 를
///   재사용하지 않고 HomeDomain 에 자체 정의한다. rawValue 는 영속/서버 호환을 위해 동일하다.
public enum ScheduleAttendanceStatus: String, CaseIterable, Equatable, Sendable {

    /// 출석 전
    case beforeAttendance = "pending"

    /// 승인 대기
    case pendingApproval

    /// 출석
    case present

    /// 지각
    case late

    /// 결석
    case absent
}

// MARK: - Server Status Mapping

public extension ScheduleAttendanceStatus {

    /// 서버 API 상태 문자열 → 도메인 enum 변환
    ///
    /// - Parameter serverStatus: 서버 응답 status 필드
    ///   (e.g., `"PRESENT"`, `"LATE"`, `"ABSENT"`, `"PENDING"`,
    ///    `"PRESENT_PENDING"`, `"LATE_PENDING"`, `"EXCUSED"`, `"EXCUSED_PENDING"`)
    init(serverStatus: String) {
        switch serverStatus {
        case "PRESENT", "EXCUSED":
            self = .present
        case "LATE":
            self = .late
        case "ABSENT":
            self = .absent
        case "PENDING":
            self = .beforeAttendance
        case "PRESENT_PENDING", "LATE_PENDING", "EXCUSED_PENDING":
            self = .pendingApproval
        default:
            // 서버에 새 PENDING 변형이 추가돼도 승인 대기로 안전하게 흡수한다.
            self = serverStatus.hasSuffix("_PENDING") ? .pendingApproval : .beforeAttendance
        }
    }
}
