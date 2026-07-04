//
//  RainbowBorderModifier.swift
//  CoreUIComponents
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI

/// 무지개 그라디언트 태두리를 적요하는 ViewModifer
public struct RainbowBorderModifier: ViewModifier {
    
    // MARK: - Property
    private let lineWidth: CGFloat
    private let shape: RainbowBorderShape
    
    // MARK: - Function
    public init(lineWidth: CGFloat, shape: RainbowBorderShape) {
        self.lineWidth = lineWidth
        self.shape = shape
    }
    
    public func body(content: Content) -> some View {
        Group {
            switch shape {
            case .circle:
                content.overlay(
                    Circle()
                        .strokeBorder(rainbowGradient, lineWidth: lineWidth)
                )
            case .roundedRectangle(let cornerRadius):
                content.overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(rainbowGradient, lineWidth: lineWidth)
                )
            case .capsule:
                content.overlay(
                    Capsule()
                        .strokeBorder(rainbowGradient, lineWidth: lineWidth)
                )
            }
        }
    }
    
    private var rainbowGradient: AngularGradient {
        AngularGradient(
            colors: [
                .red,
                .orange,
                .yellow,
                .green,
                .blue,
                .indigo,
                .purple,
                .red
            ],
            center: .center,
            angle: .degrees(.zero)
        )
    }
}

/// RainbowBorder에서 사용 가능한 Shape 타입
public enum RainbowBorderShape {
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
}

internal extension View {
    /// 무지개 그라디언트 테두리를 추가합니다.
    ///
    /// - Parameters:
    ///   - lineWidth: 테두리 두께 (기본값: 3)
    ///   - shape: 테두리 모양 (기본값: .circle)
    /// - Returns: 무지개 테두리가 적용된 View
    ///
    /// # 사용 예시
    /// ```swift
    /// Image("profile")
    ///     .rainbowBorder()
    ///
    /// Text("Hello")
    ///     .rainbowBorder(lineWidth: 2, shape: .capsule)
    ///
    /// Rectangle()
    ///     .rainbowBorder(lineWidth: 4, shape: .roundedRectangle(cornerRadius: 12))
    /// ```
    ///
    func rainbowBorder(
        lineWidth: CGFloat = 3,
        shape: RainbowBorderShape = .circle
    ) -> some View {
        modifier(RainbowBorderModifier(lineWidth: lineWidth, shape: shape))
    }
}
