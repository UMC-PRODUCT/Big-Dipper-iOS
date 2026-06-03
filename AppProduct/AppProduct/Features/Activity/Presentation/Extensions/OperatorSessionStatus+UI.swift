//
//  OperatorSessionStatus+UI.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/6/26.
//

import SwiftUI

/// OperatorSessionStatus의 UI 관련 확장
///
/// Domain에서 SwiftUI 의존성을 제거하고 Presentation 계층에서 UI 프로퍼티를 제공합니다.
extension OperatorSessionStatus {

    /// 상태 아이콘 색상
    var iconColor: Color {
        switch self {
        case .beforeStart: return .gray.opacity(0.7)
        case .inProgress: return .indigo400
        case .ended: return .green.opacity(0.7)
        }
    }

    /// 상태 텍스트 색상
    var textColor: Color {
        switch self {
        case .beforeStart: return .grey600
        case .inProgress: return .indigo500
        case .ended: return .gray
        }
    }

    /// 출석 현황 목록 카드 전용 강조 색상 (좌측 액센트 바 + 상태 배지).
    /// inProgress=진행중(브랜드 강조), beforeStart=예정(액센트), ended=마감(디엠퍼사이즈).
    var listAccentColor: Color {
        switch self {
        case .inProgress: return .indigo500
        case .beforeStart: return .orange500
        case .ended: return .grey400
        }
    }

    /// 목록 카드 상태 배지에 표시할 짧은 라벨.
    var listBadgeText: String {
        switch self {
        case .inProgress: return "진행중"
        case .beforeStart: return "예정"
        case .ended: return "마감"
        }
    }
}
