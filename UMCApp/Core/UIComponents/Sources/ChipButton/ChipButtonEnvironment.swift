//
//  ChipButtonEnvironment.swift
//  UMCApp
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI

// MARK: - Environment Keys

public struct ChipButtonSizeKey: EnvironmentKey {
    public static let defaultValue: ChipButtonSize = .medium
}

public struct ChipButtonStyleKey: EnvironmentKey {
    public static let defaultValue: ChipButtonStyle = .filter
}

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {
    public var chipButtonSize: ChipButtonSize {
        get { self[ChipButtonSizeKey.self] }
        set { self[ChipButtonSizeKey.self] = newValue }
    }
}

extension EnvironmentValues {
    public var chipButtonStyle: ChipButtonStyle {
        get { self[ChipButtonStyleKey.self] }
        set { self[ChipButtonStyleKey.self] = newValue }
    }
}
