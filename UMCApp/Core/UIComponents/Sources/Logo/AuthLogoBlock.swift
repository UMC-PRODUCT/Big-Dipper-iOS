//
//  AuthLogoBlock.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDesignSystem
import SwiftUI

/// 인증 진입 화면(BootstrapView/LoginView)에서 공통으로 사용하는 로고 + 슬로건 블록.
///
/// `BootstrapView` 의 굴절 시네마틱이 끝나는 순간과 `LoginView` 의 평소 상태가 **픽셀 단위로
/// 일치**해야 시네마틱이 단절 없이 로그인 화면으로 연결된다. 따라서 두 화면의 로고+슬로건은
/// 동일한 View 컴포넌트로 추출해 layout 차이를 원천 봉쇄한다.
///
/// `sloganOpacity` 는 `BootstrapView` 의 시네마틱 reveal 연출을 위한 옵트인 파라미터.
/// 이미지 로고는 항상 선명하게 보이고 슬로건 텍스트만 lens 가 비춰지는 동안 0 → 1 로
/// 차오르도록 호출부에서 컨트롤한다. LoginView 처럼 시네마틱 없는 호출부는 기본값(1.0)
/// 로 두면 정적 layout 그대로.
public struct AuthLogoBlock: View, Equatable {

    // MARK: - Property

    /// 슬로건(부제 + statement) 영역의 투명도(0~1). 기본 1.0 = 정적(LoginView 등).
    /// `BootstrapView` 가 시네마틱 bloom 동안 0 → 1 로 reveal 시킨다.
    private let sloganOpacity: Double

    fileprivate enum Constants {
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
