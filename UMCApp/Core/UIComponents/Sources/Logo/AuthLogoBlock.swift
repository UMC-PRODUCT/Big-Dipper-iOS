import CoreDesignSystem
import SwiftUI

/// 인증 진입 화면(LoginView 등)에서 공통으로 사용하는 로고 + 슬로건 블록.
public struct AuthLogoBlock: View, Equatable {

    // MARK: - Property

    /// 슬로건(부제 + statement) 영역의 투명도(0~1). 기본 1.0 = 정적.
    private let sloganOpacity: Double

    private enum Constants {
        static let logoImageWidth: CGFloat = 160
        static let appSubtitle: String = "동아리 활동을 한 곳에서"
        static let appStatement: String = "Focus on Growth, We Handle the Ops"
    }

    // MARK: - Init

    public init(sloganOpacity: Double = 1.0) {
        self.sloganOpacity = sloganOpacity
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Image("logoLight", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.logoImageWidth)
                .accessibilityHidden(true)
                .accessibilityIgnoresInvertColors()

            VStack(spacing: DefaultSpacing.spacing4) {
                Text(Constants.appSubtitle)
                    .appFont(.callout, color: .grey700)
                Text(Constants.appStatement)
                    .appFont(.subheadline, color: .grey500)
            }
            .opacity(sloganOpacity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "UMC University MakeUs Challenge. \(Constants.appSubtitle). \(Constants.appStatement)."
        )
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("AuthLogoBlock") {
    AuthLogoBlock()
}
#endif
