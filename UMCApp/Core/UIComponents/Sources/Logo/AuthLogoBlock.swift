import CoreDesignSystem
import SwiftUI

/// 인증 진입 화면(LoginView 등)에서 공통으로 사용하는 로고 + 슬로건 블록.
///
/// 부트스트랩 화면(`BootstrapView`)은 `ProgressView` 기반의 최소 구현이라 이 블록과
/// 픽셀 단위로 맞출 시네마틱 연출은 계획되어 있지 않다 — 정적으로 렌더링되는 로고다.
public struct AuthLogoBlock: View, Equatable {

    // MARK: - Property

    fileprivate enum Constants {
        static let logoImageWidth: CGFloat = 160
        static let appSubtitle: String = "동아리 활동을 한 곳에서"
        static let appStatement: String = "Focus on Growth, We Handle the Ops"
    }

    // MARK: - Init

    public init() {}

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
