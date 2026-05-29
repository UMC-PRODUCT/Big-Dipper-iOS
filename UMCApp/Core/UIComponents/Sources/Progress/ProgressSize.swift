//
//  ProgressSize.swift
//  UMCApp
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import SwiftUI
import CoreDesignSystem

public enum ProgressSize {
    case small
    case regular
    case large

    public var controlSize: ControlSize {
        switch self {
        case .small:
            return .small
        case .regular:
            return .regular
        case .large:
            return .large
        }
    }
    
    public var messageSize: AppFont {
        switch self {
        case .small:
            return .caption1
        case .regular:
            return .subheadline
        case .large:
            return .body
        }
    }
}
