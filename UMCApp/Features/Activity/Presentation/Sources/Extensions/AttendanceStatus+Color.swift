//
//  AttendanceStatus+Color.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 5/7/26.
//

import SwiftUI
import ActivityDomain

/// `AttendanceStatus` 의 시각 표현 매핑.
///
/// 도메인 enum 자체는 SwiftUI 의존을 갖지 않도록 분리되어 있으며,
/// 본 extension 은 Presentation 레이어 전용 색상 매핑을 제공합니다.
public extension AttendanceStatus {

    /// 배지/버튼 배경 색상
    var backgroundColor: Color {
        switch self {
        case .beforeAttendance: return .gray.opacity(0.7)
        case .pendingApproval:  return .yellow.opacity(0.7)
        case .present:          return .green.opacity(0.7)
        case .late:             return .yellow.opacity(0.7)
        case .absent:           return .red.opacity(0.7)
        }
    }

    /// 배지/버튼 폰트 색상
    var fontColor: Color {
        .white
    }
}
