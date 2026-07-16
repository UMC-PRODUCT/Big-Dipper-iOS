//
//  MainButtonModifiers.swift
//  CoreUIComponents
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI

// MARK: - AnyMainButton Protocol

/// MainButton 전용 프로토콜
/// 이 프로토콜을 준수하는 View만 MainButton modifier 사용 가능
public protocol AnyMainButton: View { }

// MARK: - ViewModifiers

public struct MainButtonSizeModifier: ViewModifier {
    public let size: MainButtonSize

    public func body(content: Content) -> some View {
        content.environment(\.mainButtonSize, size)
    }
}

public struct MainButtonLoadingModifier: ViewModifier {
    @Binding public var isLoading: Bool

    public func body(content: Content) -> some View {
        content.environment(\.mainButtonIsLoading, isLoading)
    }
}

// MARK: - AnyMainButton Extension

extension AnyMainButton {

    /// 버튼 사이즈 설정
    /// - Parameter size: small, medium, large
    public func buttonSize(_ size: MainButtonSize) -> some View {
        self.modifier(MainButtonSizeModifier(size: size))
    }

    /// 로딩 상태 바인딩
    /// - Parameter isLoading: 로딩 상태 Binding
    public func loading(_ isLoading: Binding<Bool>) -> some View {
        self.modifier(MainButtonLoadingModifier(isLoading: isLoading))
    }
}
