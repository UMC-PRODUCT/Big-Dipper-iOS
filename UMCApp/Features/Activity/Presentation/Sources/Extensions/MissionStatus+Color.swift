//
//  MissionStatus+Color.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI
import ActivityDomain
import CoreDesignSystem

/// `MissionStatus` 의 시각 표현 매핑.
///
/// 도메인 enum 자체는 SwiftUI 의존을 갖지 않도록 분리되어 있으며,
/// 본 extension 은 Presentation 레이어 전용 색상 매핑을 제공합니다.
extension MissionStatus {

    /// 주차 배지 배경 색상
    var backgroundColor: Color {
        switch self {
        case .notStarted:      return .gray.opacity(0.4)
        case .inProgress:      return .indigo200
        case .pendingApproval: return .orange.opacity(0.4)
        case .pass:            return .green.opacity(0.4)
        case .fail:            return .red.opacity(0.4)
        case .completed:       return .green.opacity(0.4)
        case .locked:          return .grey200
        }
    }

    /// 미션 리스트 좌측 상태 아이콘 색상
    var missionListIconColor: Color {
        switch self {
        case .notStarted:      return .gray.opacity(0.7)
        case .inProgress:      return .indigo400
        case .pendingApproval: return .orange.opacity(0.7)
        case .pass:            return .green.opacity(0.7)
        case .fail:            return .red.opacity(0.7)
        case .completed:       return .green.opacity(0.7)
        case .locked:          return .grey400
        }
    }

    /// 상태 텍스트/숫자 전경 색상
    var foregroundColor: Color {
        switch self {
        case .notStarted:      return .grey600
        case .inProgress:      return .indigo500
        case .pendingApproval: return .orange
        case .pass:            return .green700
        case .fail:            return .red
        case .completed:       return .green700
        case .locked:          return .grey400
        }
    }
}
