//
//  ChipButtonStyle.swift
//  UMCApp
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import SwiftUI

// MARK: - ChipButtonStyle

/// ChipButton 사이즈 유형
public enum ChipButtonStyle {
    // 공지 리스트 필터(전체, 중앙운영사무국, 지부, 학교)
    case filter

    // 공지 작성: 게시판 분류(전체, 운영진 공지, 파트, 학교)
    case board

    // 커뮤니티: 명예의 전당 (주차)
    case fame

    public func textColor(isSelected: Bool) -> Color {
        switch self {
        case .filter:
            return isSelected ? .grey000 : .grey600
        case .board:
            return .grey000
        case .fame:
            return isSelected ? .white : .grey600
        }
    }

    public func bgColor(isSelected: Bool) -> Color {
        switch self {
        case .filter:
            return isSelected ? .indigo500 : .grey200
        case .board:
            return isSelected ? .indigo500 : .grey300
        case .fame:
            return isSelected ? .yellow500 : .white
        }
    }
}
