import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 소셜 로그인 버튼 라벨 (브랜드 컬러 캡슐)
///
/// 좌측 로고 + 중앙 정렬 텍스트로 구성된 풀-위드 캡슐 버튼 라벨.
/// 디자인 시스템 토큰만 사용하며, 브랜드 색은 `SocialType`에서 주입된다.
public struct SocialLoginLabel: View {

    // MARK: - Property

    private let loginType: SocialType

    private enum Constants {
        static let leadingPadding: CGFloat = 16
        static let buttonHeight: CGFloat = 48
    }

    // MARK: - Init

    public init(_ loginType: SocialType) {
        self.loginType = loginType
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .leading) {
            Text(loginType.loginButtonTitle)
                .appFont(.callout, color: loginType.fontColor)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.buttonHeight)
                .background(loginType.color, in: .capsule)

            loginLogo
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var loginLogo: some View {
        loginType.image
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: loginType.iconSize, height: loginType.iconSize)
            .accessibilityHidden(true)
            .padding(.leading, Constants.leadingPadding)
    }
}

#if DEBUG
#Preview("SocialLoginLabel — 3종") {
    VStack(spacing: 12) {
        SocialLoginLabel(.kakao)
        SocialLoginLabel(.apple)
        SocialLoginLabel(.google)
    }
    .padding()
}
#endif
