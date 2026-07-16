//
//  ArticleTextFieldType.swift
//  CoreUIComponents
//
//  Created by 이예지 on 7/3/26.
//

import Foundation
import SwiftUI
import CoreDesignSystem

public enum ArticleTextFieldType {
    case title
    case content
    
    public var placeholderLabel: String {
        switch self {
        case .title:
            return "제목을 입력하세요."
        case .content:
            return "내용을 입력하세요."
        }
    }
    
    public var placeholderFont: AppFont {
        switch self {
        case .title:
            return .title3
        case .content:
            return .body
        }
    }
    
    public var placeholderWeight: AppFontWeight {
        switch self {
        case .title:
            return .semibold
        case .content:
            return .regular
        }
    }
    
    public var axis: Axis {
        switch self {
        case .title:
            return .horizontal
        case .content:
            return .vertical
        }
    }
    
    public var scrollIndicator: ScrollIndicatorVisibility {
        switch self {
        case .title:
            return .hidden
        case .content:
            return .visible
        }
    }
}
