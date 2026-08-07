//
//  MyAttendanceItemStatus+Color.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 5/7/26.
//

import SwiftUI
import ActivityDomain
import CoreUIComponents

/// `MyAttendanceItemStatus` 의 시각 표현 매핑.
///
/// 도메인 enum 자체는 SwiftUI 의존을 갖지 않도록 분리되어 있으며,
/// 본 extension 은 Presentation 레이어 전용 색상 매핑을 제공합니다.
public extension MyAttendanceItemStatus {

    /// 배지/버튼 배경 색상
    var backgroundColor: Color {
        badgeStatus.backgroundColor
    }

    /// 배지/버튼 폰트 색상
    var fontColor: Color {
        badgeStatus.foregroundColor
    }
}

extension MyAttendanceItemStatus {

    /// 공용 뱃지 색 매핑(``AttendanceBadgeStatus``)으로 변환한다. 색상만 사용한다.
    /// `default` 를 두지 않아 도메인 케이스 추가 시 컴파일 단계에서 누락이 드러난다.
    var badgeStatus: AttendanceBadgeStatus {
        switch self {
        case .pendingApproval: return .presentPending
        case .present:         return .present
        case .late:            return .late
        case .absent:          return .absent
        }
    }
}
