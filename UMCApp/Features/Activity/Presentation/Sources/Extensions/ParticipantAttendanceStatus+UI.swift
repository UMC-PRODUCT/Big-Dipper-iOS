//
//  ParticipantAttendanceStatus+UI.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import SwiftUI

/// `ParticipantAttendanceStatus` 의 시각 표현 매핑.
///
/// 도메인 enum 이 SwiftUI 의존을 갖지 않도록 아이콘·색상은 Presentation 레이어에 둡니다.
/// 필터 메뉴(``OperatorAttendanceView``)와 상태 뱃지(``AttendanceStatusBadge``)가 공유합니다.
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

    /// 상태 뱃지 글래스 틴트 색상
    var badgeTintColor: Color {
        switch self {
        case .present, .excused:
            return .green
        case .late:
            return .orange
        case .absent:
            return .red
        case .presentPending, .latePending, .excusedPending:
            return .yellow
        case .pending, .unknown:
            return .gray
        }
    }

    /// 상태 뱃지 전경(텍스트·아이콘) 색상
    ///
    /// 승인 대기는 노랑 틴트 위에서 대비가 부족해 주황 전경을 사용합니다.
    var badgeForegroundColor: Color {
        switch self {
        case .present, .excused:
            return .green
        case .late:
            return .orange
        case .absent:
            return .red
        case .presentPending, .latePending, .excusedPending:
            return .orange
        case .pending, .unknown:
            return .grey600
        }
    }
}
