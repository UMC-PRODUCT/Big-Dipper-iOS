//
//  SocialLoginLabel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/27/26.
//
//  소셜 로그인 버튼 라벨 — 브랜드 색 캡슐 + 좌측 로고 + 중앙 텍스트.
//
//  AuthBootstrapView 와 LoginView 양쪽에서 동일한 시각을 보장하기 위해 별도 파일로 분리한다.
//

import SwiftUI

/// 소셜 로그인 버튼 라벨 (브랜드 컬러 캡슐)
///
/// 좌측 로고(`SocialType.iconSize`) + 중앙 정렬 텍스트로 구성된 풀-위드 캡슐 버튼 라벨.
/// 디자인 시스템 토큰만 사용하며, 브랜드 색은 `SocialType` 에서 주입된다.
struct SocialLoginLabel: View {

    // MARK: - Property

    let loginType: SocialType

    private enum LayoutConstants {
        static let leadingPadding: CGFloat = 16
        static let buttonHeight: CGFloat = 48
    }

    // MARK: - Init

    init(_ loginType: SocialType) {
        self.loginType = loginType
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            Text(loginType.rawValue)
                .appFont(.callout, color: loginType.fontColor)
                .frame(maxWidth: .infinity)
                .frame(height: LayoutConstants.buttonHeight)
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
            .padding(.leading, LayoutConstants.leadingPadding)
    }
}

#if DEBUG
#Preview("SocialLoginLabel — 3종") {
    VStack(spacing: 12) {
        SocialLoginLabel(.kakao)
        SocialLoginLabel(.apple)
        SocialLoginLabel(.email)
    }
    .padding()
}
#endif
