//
//  DefaultBackgroundModifier.swift
//  CoreDesignSystem
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import CoreDesignSystem

public struct DefaultBackgroundModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content.background(Color.grey100.opacity(0.55))
    }
}

extension View {
    public func umcDefaultBackground() -> some View {
        modifier(DefaultBackgroundModifier())
    }
}
