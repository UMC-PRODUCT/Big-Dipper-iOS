//
//  ScheduleIconCategory+Visual.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 5/7/26.
//

import SwiftUI
import CoreDesignSystem
import UMCFoundation

/// `ScheduleIconCategory` 에 대한 시각 표현(SF Symbol, 테마 색상) 매핑.
///
/// raw 값 매핑은 `UMCFoundation` 의 enum 정의에 위치하고,
/// SwiftUI 의존이 필요한 시각 토큰만 본 모듈에 분리합니다.
///
/// - Note: 도메인 enum → 시각 표현 매핑은 `CoreUIComponents/Extensions/` 에 둡니다.
///   `CoreDesignSystem` 은 디자인 토큰(색상/타입/간격) 전용 레이어이므로
///   도메인(UMCFoundation) 의존을 갖지 않습니다.
public extension ScheduleIconCategory {

    /// 카테고리별 시스템 심볼 이미지 이름
    var symbol: String {
        switch self {
        case .leadership:   return "person.3.sequence.fill"
        case .study:        return "book.closed.fill"
        case .fee:          return "wonsign.circle.fill"
        case .meeting:      return "person.2.fill"
        case .networking:   return "bubble.left.and.bubble.right.fill"
        case .hackathon:    return "laptopcomputer"
        case .project:      return "hammer.fill"
        case .presentation: return "mic.fill"
        case .workshop:     return "tent.fill"
        case .review:       return "lightbulb.fill"
        case .celebration:  return "sparkles"
        case .orientation:  return "megaphone.fill"
        case .testing:      return "chevron.left.forwardslash.chevron.right"
        case .general:      return "calendar.badge"
        }
    }

    /// 카테고리별 테마 색상
    var color: Color {
        switch self {
        case .leadership:   return .indigo
        case .study:        return .blue
        case .fee:          return .green
        case .meeting:      return .cyan
        case .networking:   return .teal
        case .hackathon:    return .purple
        case .project:      return .orange
        case .presentation: return .red
        case .workshop:     return .mint
        case .review:       return .yellow
        case .celebration:  return .accentColor
        case .orientation:  return .orange
        case .testing:      return .gray
        case .general:      return .indigo500
        }
    }
}
