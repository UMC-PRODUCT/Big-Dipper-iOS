//
//  ChipButtonSize.swift
//  UMCApp
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - ChipButtonSize

/// ChipButton 사이즈 유형
public enum ChipButtonSize {
    case small
    case medium
    case large
    
    public var horizonPadding: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 16
        case .large:
            return 16
        }
    }
    
    public var font: Font {
        switch self {
        case .small:
            return .app(.footnote, weight: .semibold)
        case .medium:
            return .app(.subheadline, weight: .semibold)
        case .large:
            return .app(.callout, weight: .semibold)
        }
    }
}
