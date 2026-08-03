//
//  ParticipantAttendanceStatus+UI.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreUIComponents
import Foundation

/// `ParticipantAttendanceStatus` 의 표현 계층 매핑.
///
/// 도메인 enum 이 SwiftUI 의존을 갖지 않도록 아이콘과 뱃지 매핑은 Presentation 레이어에 둡니다.
extension ParticipantAttendanceStatus {

    /// 필터 메뉴 라벨에 사용할 SF Symbol 이름
    var iconName: String {
        switch self {
        case .present:        return "checkmark.circle.fill"
        case .presentPending: return "checkmark.circle"
        case .late:           return "clock.fill"
        case .latePending:    return "clock"
        case .absent:         return "xmark.circle.fill"
        case .excused:        return "text.bubble.fill"
        case .excusedPending: return "text.bubble"
        case .pending:        return "circle.dashed"
        case .unknown:        return "questionmark.circle"
        }
    }

    /// 공용 뱃지(``AttendanceStatusBadge``)가 요구하는 Core-safe 상태로 변환한다.
    ///
    /// `CoreUIComponents` 는 ActivityDomain 에 의존할 수 없어 같은 케이스 집합을
    /// ``AttendanceBadgeStatus`` 로 자체 보유하며, 매핑은 각 피처의 Presentation 몫입니다.
    /// `default` 를 두지 않아 도메인에 케이스가 추가되면 컴파일 단계에서 매핑 누락이 드러납니다.
    var badgeStatus: AttendanceBadgeStatus {
        switch self {
        case .presentPending: return .presentPending
        case .latePending:    return .latePending
        case .excusedPending: return .excusedPending
        case .present:        return .present
        case .late:           return .late
        case .absent:         return .absent
        case .excused:        return .excused
        case .pending:        return .pending
        case .unknown:        return .unknown
        }
    }
}
