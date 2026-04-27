import SwiftUI

private enum ButtonConstants {
    static let height: CGFloat = 44
    static let cornerRadius: CGFloat = 8
}

// MARK: - PrimaryButtonStyle

/// 주요 액션에 사용
public struct PrimaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.body, color: .grey000)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonConstants.height)
            .background(
                isEnabled
                    ? (configuration.isPressed ? Color.indigo600 : Color.indigo500)
                    : Color.grey400,
                in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius)
            )
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - SecondaryButtonStyle

/// 보조 액션에 사용
public struct SecondaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
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

/// 삭제, 취소 등 위험한 액션에 사용
public struct DestructiveButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.bodyEmphasis)
            .foregroundStyle(Color.grey000)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonConstants.height)
            .background(
                isEnabled
                    ? (configuration.isPressed ? Color.red.opacity(0.7) : Color.red.opacity(0.9))
                    : Color.grey400,
                in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius)
            )
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - TextButtonStyle

/// 링크 스타일 액션에 사용
public struct TextButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
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

// MARK: - Button Extension

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

public extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

public extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
}
