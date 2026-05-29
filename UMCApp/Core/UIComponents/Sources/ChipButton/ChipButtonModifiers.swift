//
//  ChipButtonModifiers.swift
//  UMCApp
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI

// MARK: - AnyChipButton Protocol

/// ChipButton 전용 프로토콜
public protocol AnyChipButton: View {}

// MARK: - ViewModifiers

public struct ChipButtonSizeModifier: ViewModifier {
    public let size: ChipButtonSize

    public func body(content: Content) -> some View {
        content.environment(\.chipButtonSize, size)
    }
}

public struct ChipButtonStyleModifier: ViewModifier {
    public let style: ChipButtonStyle

    public func body(content: Content) -> some View {
        content.environment(\.chipButtonStyle, style)
    }
}

// MARK: - AnyChipButton Extension

extension AnyChipButton {
    /// ChipButton 사이즈 설정
    /// - Parameter size: small, medium, large
    public func buttonSize(_ size: ChipButtonSize) -> some View {
        modifier(ChipButtonSizeModifier(size: size))
    }

    /// 버튼 색상 설정
    /// - Parameter style: filter, board, fame
    public func buttonStyle(_ style: ChipButtonStyle) -> some View {
        modifier(ChipButtonStyleModifier(style: style))
    }
}
