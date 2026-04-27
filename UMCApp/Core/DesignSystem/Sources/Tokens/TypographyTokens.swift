import SwiftUI

// MARK: - AppFont

public enum AppFont {
    case largeTitle
    case title1
    case title2
    case title3
    case body
    case callout
    case subheadline
    case footnote
    case caption1
    case caption2

    case largeTitleEmphasis
    case title1Emphasis
    case title2Emphasis
    case title3Emphasis
    case bodyEmphasis
    case calloutEmphasis
    case subheadlineEmphasis
    case footnoteEmphasis
    case caption1Emphasis
    case caption2Emphasis

    private var baseStyle: AppFont {
        switch self {
        case .largeTitleEmphasis:  return .largeTitle
        case .title1Emphasis:      return .title1
        case .title2Emphasis:      return .title2
        case .title3Emphasis:      return .title3
        case .bodyEmphasis:        return .body
        case .calloutEmphasis:     return .callout
        case .subheadlineEmphasis: return .subheadline
        case .footnoteEmphasis:    return .footnote
        case .caption1Emphasis:    return .caption1
        case .caption2Emphasis:    return .caption2
        default:                   return self
        }
    }

    public var isEmphasis: Bool {
        switch self {
        case .largeTitleEmphasis, .title1Emphasis, .title2Emphasis, .title3Emphasis,
             .bodyEmphasis, .calloutEmphasis, .subheadlineEmphasis,
             .footnoteEmphasis, .caption1Emphasis, .caption2Emphasis:
            return true
        default:
            return false
        }
    }

    public var size: CGFloat {
        switch self {
        case .largeTitle, .largeTitleEmphasis:     return 34
        case .title1, .title1Emphasis:             return 28
        case .title2, .title2Emphasis:             return 22
        case .title3, .title3Emphasis:             return 20
        case .body, .bodyEmphasis:                 return 17
        case .callout, .calloutEmphasis:           return 16
        case .subheadline, .subheadlineEmphasis:   return 15
        case .footnote, .footnoteEmphasis:         return 13
        case .caption1, .caption1Emphasis:         return 12
        case .caption2, .caption2Emphasis:         return 11
        }
    }

    public var lineHeightMultiplier: CGFloat {
        switch baseStyle {
        case .largeTitle:  return 1.21
        case .title1:      return 1.21
        case .title2:      return 1.27
        case .title3:      return 1.25
        case .body:        return 1.38
        case .callout:     return 1.31
        case .subheadline: return 1.33
        case .footnote:    return 1.38
        case .caption1:    return 1.33
        case .caption2:    return 1.18
        default:           return 1.0
        }
    }

    public var lineHeight: CGFloat { size * lineHeightMultiplier }
    public var lineSpacing: CGFloat { lineHeight - size }

    public var textStyle: Font.TextStyle {
        switch baseStyle {
        case .largeTitle:  return .largeTitle
        case .title1:      return .title
        case .title2:      return .title2
        case .title3:      return .title3
        case .body:        return .body
        case .callout:     return .callout
        case .subheadline: return .subheadline
        case .footnote:    return .footnote
        case .caption1:    return .caption
        case .caption2:    return .caption2
        default:           return .body
        }
    }
}

// MARK: - AppFontWeight

public enum AppFontWeight {
    case regular
    case medium
    case semibold

    public var fontName: String {
        switch self {
        case .regular:  return "Pretendard-Regular"
        case .medium:   return "Pretendard-Medium"
        case .semibold: return "Pretendard-SemiBold"
        }
    }

    public var swiftUIWeight: Font.Weight {
        switch self {
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        }
    }
}

// MARK: - Font Extension

public extension Font {
    static func app(_ style: AppFont, weight: AppFontWeight? = nil) -> Font {
        let finalWeight = weight ?? (style.isEmphasis ? .semibold : .regular)
        return .custom(finalWeight.fontName, size: style.size, relativeTo: style.textStyle)
    }

    static func app(size: CGFloat, weight: AppFontWeight = .medium) -> Font {
        .custom(weight.fontName, size: size)
    }
}

// MARK: - View Extension

public extension View {
    @ViewBuilder
    func appFont(
        _ style: AppFont,
        weight: AppFontWeight? = nil,
        color: Color? = nil
    ) -> some View {
        let view = self
            .font(.app(style, weight: weight))
            .lineSpacing(style.lineSpacing)
        if let color {
            view.foregroundStyle(color)
        } else {
            view
        }
    }
}
