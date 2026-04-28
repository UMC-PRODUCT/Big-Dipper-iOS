import SwiftUI

public enum AppColor {

    // MARK: - Grey

    case grey000, grey100, grey200, grey300, grey400
    case grey500, grey600, grey700, grey800, grey900

    // MARK: - Primary (Indigo)

    case indigo100, indigo200, indigo300, indigo400, indigo500
    case indigo600, indigo700, indigo800, indigo900

    // MARK: - Accent (Orange)

    case orange100, orange200, orange300, orange400, orange500
    case orange600, orange700, orange800, orange900

    // MARK: - Semantic

    case red100, red300, red500, red700, red900
    case green100, green300, green500, green700, green900
    case yellow100, yellow300, yellow500, yellow700, yellow900

    // MARK: - ETC

    case kakao
    case etc000

    public var swiftUIColor: Color {
        switch self {
        case .grey000:   return .grey000
        case .grey100:   return .grey100
        case .grey200:   return .grey200
        case .grey300:   return .grey300
        case .grey400:   return .grey400
        case .grey500:   return .grey500
        case .grey600:   return .grey600
        case .grey700:   return .grey700
        case .grey800:   return .grey800
        case .grey900:   return .grey900

        case .indigo100: return .indigo100
        case .indigo200: return .indigo200
        case .indigo300: return .indigo300
        case .indigo400: return .indigo400
        case .indigo500: return .indigo500
        case .indigo600: return .indigo600
        case .indigo700: return .indigo700
        case .indigo800: return .indigo800
        case .indigo900: return .indigo900

        case .orange100: return .orange100
        case .orange200: return .orange200
        case .orange300: return .orange300
        case .orange400: return .orange400
        case .orange500: return .orange500
        case .orange600: return .orange600
        case .orange700: return .orange700
        case .orange800: return .orange800
        case .orange900: return .orange900

        case .red100:    return .red100
        case .red300:    return .red300
        case .red500:    return .red500
        case .red700:    return .red700
        case .red900:    return .red900

        case .green100:  return .green100
        case .green300:  return .green300
        case .green500:  return .green500
        case .green700:  return .green700
        case .green900:  return .green900

        case .yellow100: return .yellow100
        case .yellow300: return .yellow300
        case .yellow500: return .yellow500
        case .yellow700: return .yellow700
        case .yellow900: return .yellow900

        case .kakao:     return .kakao
        case .etc000:    return .etc000
        }
    }
}
