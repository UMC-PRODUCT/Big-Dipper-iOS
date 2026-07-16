//
//  MainButtonSize.swift
//  CoreUIComponents
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - MainButtonSize

/// MainButton 사이즈 유형 (향후 확장용)
public enum MainButtonSize {
    case small
    case medium
    case large

    public var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 52
        }
    }

    public var font: Font {
        switch self {
        case .small: return .app(.footnote, weight: .semibold)
        case .medium: return .app(.body, weight: .semibold)
        case .large: return .app(.title3, weight: .semibold)
        }
    }
}
