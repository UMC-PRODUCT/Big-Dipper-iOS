//
//  ExchangeSearchingView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/19/26.
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents

/// 교환 탐색 중 상태 — 시안 `마이페이지_명함교환_wifi` (`Figma 12654:32255`).
///
/// 배지·레이더·문구의 배치와 치수는 시안 실측 그대로다. 다만 시안 문구는 Wi-Fi Aware 를
/// 전제하는데 transport 는 MPC 로 확정됐다(2026-08-17, Wi-Fi Aware 폐기) — 기술명이
/// 화면에 남으면 거짓이 되므로 배지는 「근거리 탐색」, 안내문의 강조 스팬은 상대가 실제로
/// 누르는 버튼명 「명함 교환」으로 바꿔 싣는다.
struct ExchangeSearchingView: View {

    // MARK: - Property

    /// 레이더 중앙에 실을 내 아바타 (시안 더미는 UMC 로고). 없으면 플레이스홀더가 뜬다.
    let avatarURL: String?

    // MARK: - Constants

    private enum Constants {
        static let badgeIcon = "wifi"
        static let badgeTitle = "근거리 탐색"
        static let title = "주변 UMC 멤버를 찾는 중…"
        static let captionPrefix = "상대방도 ‘"
        static let captionEmphasis = "명함 교환"
        static let captionSuffix = "’을 누르면 여기에 나타나요"
    }

    private enum Metrics {
        /// 시안 12654:32590 — 배지 · 레이더 · 문구 사이 간격 40, 툴바 아래 여백.
        static let sectionSpacing: CGFloat = 40
        static let topPadding: CGFloat = 20

        static let badgeSpacing: CGFloat = 8
        static let badgeIconBox: CGFloat = 27
        static let badgeIconGlyph: CGFloat = 17
        static let badgeHorizontalPadding: CGFloat = 12
        static let badgeVerticalPadding: CGFloat = 8
        static let badgeCornerRadius: CGFloat = 27
        /// 시안 그림자 0 2 8 rgba(0,0,0,0.1). CSS 흐림 반경은 SwiftUI 의 약 두 배다.
        static let badgeShadowRadius: CGFloat = 4
        static let badgeShadowY: CGFloat = 2
        static let badgeShadowOpacity: Double = 0.1

        static let radarSize: CGFloat = 364
        static let avatarSize: CGFloat = 80

        /// 시안 문구 폭. **상한**으로 둔다 — 고정하면 큰 글자에서 줄이 넘친다.
        static let captionMaxWidth: CGFloat = 266
        static let captionSpacing: CGFloat = 5
    }

    /// 시안 레이더 원 4개 (바깥→안). 색은 코어 `indigo500`(#4869F0) — 시안 SVG 원값과 같다.
    /// 두 번째 원만 면(fill), 나머지는 1pt 선(stroke)이다.
    private static let rings: [(size: CGFloat, opacity: Double, isFilled: Bool)] = [
        (364, 0.10, false),
        (300, 0.05, true),
        (230, 0.15, false),
        (160, 0.15, false),
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            badge
            radar
            caption
        }
        .padding(.top, Metrics.topPadding)
        .frame(maxWidth: .infinity)
    }

    // MARK: - View Component

    private var badge: some View {
        HStack(spacing: Metrics.badgeSpacing) {
            Image(systemName: Constants.badgeIcon)
                .font(.system(size: Metrics.badgeIconGlyph))
                .foregroundStyle(Color.indigo500)
                .frame(minWidth: Metrics.badgeIconBox, minHeight: Metrics.badgeIconBox)
                // 옆 문구가 같은 뜻을 말한다 — 「wifi」까지 읽히면 겹친다.
                .accessibilityHidden(true)

            Text(Constants.badgeTitle)
                // `.black` 리터럴은 다크 모드에서 검정 배경 위 검정 글씨가 된다.
                // `.grey900` 은 Asset Catalog 라 다크에서 흰색으로 뒤집힌다.
                .appFont(.subheadline, weight: .semibold, color: .grey900)
        }
        .padding(.horizontal, Metrics.badgeHorizontalPadding)
        .padding(.vertical, Metrics.badgeVerticalPadding)
        .background(
            Color.grey000,
            in: RoundedRectangle(cornerRadius: Metrics.badgeCornerRadius)
        )
        .shadow(
            color: .black.opacity(Metrics.badgeShadowOpacity),
            radius: Metrics.badgeShadowRadius,
            y: Metrics.badgeShadowY
        )
    }

    /// 시안 실측은 364pt 고정이지만 화면 폭이 그보다 좁으면(SE 320) 바깥 링이 양옆으로
    /// 잘린다. 정사각 컨테이너가 남는 폭까지만 차지하게 두고(최대 364) 링·아바타를 그 비율로
    /// 줄여, 어느 기기에서도 원이 온전히 들어오고 세로 여백도 함께 줄어들게 한다.
    private var radar: some View {
        Color.clear
            .frame(maxWidth: Metrics.radarSize)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let scale = proxy.size.width / Metrics.radarSize

                    ZStack {
                        ForEach(Self.rings, id: \.size) { ring in
                            ringShape(ring, scale: scale)
                        }

                        avatar(scale: scale)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            // 탐색 중이라는 사실은 아래 문구가 말한다. 링과 아바타는 그 시각 표현이다.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func ringShape(
        _ ring: (size: CGFloat, opacity: Double, isFilled: Bool),
        scale: CGFloat
    ) -> some View {
        let diameter = ring.size * scale

        if ring.isFilled {
            Circle()
                .fill(Color.indigo500.opacity(ring.opacity))
                .frame(width: diameter, height: diameter)
        } else {
            Circle()
                .stroke(Color.indigo500.opacity(ring.opacity), lineWidth: 1)
                .frame(width: diameter, height: diameter)
        }
    }

    private func avatar(scale: CGFloat) -> some View {
        let size = Metrics.avatarSize * scale

        return RemoteImage(
            urlString: avatarURL ?? "",
            size: CGSize(width: size, height: size),
            cornerRadius: size / 2
        )
    }

    private var caption: some View {
        VStack(spacing: Metrics.captionSpacing) {
            Text(Constants.title)
                .appFont(.title3, weight: .semibold, color: .grey900)

            Text("\(Constants.captionPrefix)\(emphasizedButtonName)\(Constants.captionSuffix)")
                .appFont(.subheadline, color: .grey500)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: Metrics.captionMaxWidth)
        .accessibilityElement(children: .combine)
    }

    /// 안내문 속 강조 스팬 — 시안이 버튼명만 Bold 로 싣는다.
    ///
    /// `AppFontWeight` 는 regular/medium/semibold 3종뿐이라 semibold 로 근사한다.
    /// 확장하려면 `Core/DesignSystem/Resources/Fonts/` 에 `Pretendard-Bold.otf` 가
    /// 먼저 들어와야 한다 — 파일 없이 케이스만 늘리면 `Font.custom` 이 조용히
    /// 시스템 서체로 떨어진다 (#1237).
    ///
    /// 바깥 `appFont` 는 환경 폰트라 이 명시 폰트가 이긴다.
    private var emphasizedButtonName: Text {
        Text(Constants.captionEmphasis).font(.app(.subheadline, weight: .semibold))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("교환 탐색 중") {
    VStack {
        ExchangeSearchingView(avatarURL: nil)
        Spacer()
    }
}
#endif
