//
//  ShadowReuse.swift
//  CoreDesignSystem
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import SwiftUI
import CoreDesignSystem

/// shadow1 modifier
public struct Shadow1: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .shadow(color: .grey900.opacity(0.03), radius: 4, x: 0, y: 8)
            .shadow(color: .grey900.opacity(0.03), radius: 2, x: 1, y: 3)
            .shadow(color: .grey900.opacity(0.03), radius: 3, x: 0, y: 2)
    }
}

/// 카드 표면용 drop shadow 2단.
///
/// 이름과 달리 Liquid Glass(`.glassEffect`)가 아니라 불투명 배경 위에 얹는 그림자다.
public struct CardShadow: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 8)
            .shadow(color: .black.opacity(0.03), radius: 2, x: 1, y: 3)
    }
}

public struct BlurShadow: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .shadow(color: Color(red: 0.56, green: 0.56, blue: 0.58).opacity(0.05), radius: 4, x: 0, y: -14)
    }
}

extension View {
    public func shadow1() -> some View {
        self.modifier(Shadow1())
    }
    
    public func cardShadow() -> some View {
        self.modifier(CardShadow())
    }
    
    public func blurShadow() -> some View {
        self.modifier(BlurShadow())
    }
}
