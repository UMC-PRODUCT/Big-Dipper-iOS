//
//  ButtonStyles.swift
//  AppProduct
//
//  Created by jaewon Lee on 2026-01-01.
//

import SwiftUI

// MARK: - Constant
private enum ButtonConstants {
    static let height: CGFloat = 44
    static let cornerRadius: CGFloat = 8
}

// MARK: - PrimaryButtonStyle

/// Primary 버튼 스타일
/// 주요 액션에 사용
struct PrimaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.body, color: .grey000)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonConstants.height)
            .background(isEnabled
                        ? (configuration.isPressed ? Color.indigo600 : Color.indigo500) : Color.grey400,
                        in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - SecondaryButtonStyle

/// Secondary 버튼 스타일
/// 보조 액션에 사용
struct SecondaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.bodyEmphasis)
            .foregroundStyle(
                isEnabled
                    ? (configuration.isPressed ? Color.indigo600 : Color.indigo500)
                    : Color.grey400
            )
            .frame(maxWidth: .infinity)
            .frame(height: ButtonConstants.height)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: ButtonConstants.cornerRadius)
                    .stroke(
                        isEnabled
                            ? (configuration.isPressed ? Color.indigo600 : Color.indigo500)
                            : Color.grey400,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - DestructiveButtonStyle

/// Destructive 버튼 스타일
/// 삭제, 취소 등 위험한 액션에 사용
struct DestructiveButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.bodyEmphasis)
            .foregroundStyle(Color.grey000)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonConstants.height)
            .background(isEnabled
                        ? (configuration.isPressed ? Color.red.opacity(0.7) : Color.red.opacity(0.9)) : Color.grey400,
                        in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - TextButtonStyle

/// 텍스트 버튼 스타일
/// 링크 스타일 액션에 사용
struct TextButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.body))
            .foregroundStyle(
                isEnabled
                    ? (configuration.isPressed ? Color.indigo600 : Color.indigo500)
                    : Color.grey400
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - GradientCapsuleButtonStyle

/// 그라데이션 캡슐 버튼 스타일
///
/// 로그인 등 Primary CTA에 사용. `indigo400 → indigo600` 수평 그라데이션.
/// disabled 상태에서는 `grey400` 단색으로 폴백합니다.
struct GradientCapsuleButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    private enum LayoutConstants {
        static let height: CGFloat = 52
    }

    private var background: AnyShapeStyle {
        if isEnabled {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.indigo400, Color.indigo600],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            return AnyShapeStyle(Color.grey400)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.calloutEmphasis, color: .grey000)
            .frame(maxWidth: .infinity)
            .frame(height: LayoutConstants.height)
            .background(background, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Extension

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
}

extension ButtonStyle where Self == GradientCapsuleButtonStyle {
    static var gradientCapsule: GradientCapsuleButtonStyle { GradientCapsuleButtonStyle() }
}
