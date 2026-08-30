//
//  BusinessCardSummaryView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI
import BusinessCardDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

/// 명함 요약 스트립 — 시안 `명함_m` (372×112, `Figma 12639:33316`).
///
/// 마이페이지 루트의 `명함_l`(372×205, ``BusinessCardFaceView``)과 **별개 컴포넌트**다.
/// variant 가 아니라 Figma 에 컴포넌트 둘로 존재하고, 그라디언트 각도·알파부터
/// 아바타·이름 크기까지 다르다. 로고 헤더·플립 버튼·하단 액션 버튼은 여기 없다.
struct BusinessCardSummaryView: View {

    // MARK: - Property

    let card: MyCard

    // MARK: - Constants

    private enum Metrics {
        /// 시안 실측 폭(402pt 화면에서 좌우 16 마진). 폭은 유동으로 둔다.
        static let referenceWidth: CGFloat = 370
        /// 시안 실측 높이. **바닥값**이다 — 글자가 커지면 카드가 따라 늘어난다.
        static let minHeight: CGFloat = 112
        static let cornerRadius: CGFloat = 34
        static let padding: CGFloat = 16
        static let avatarSize: CGFloat = 80
        /// 아바타 ↔ 텍스트 블록, 이름 행 ↔ 칩 행.
        static let blockSpacing: CGFloat = 16
        static let nameSpacing: CGFloat = 8
        static let chipSpacing: CGFloat = 5
    }

    /// 전부 코어 토큰이다 (#1237) — 라이트 전용 raw hex 를 걷어냈다.
    private enum Palette {
        /// 시안 `linear-gradient(126.738deg, rgba(114,142,253,0.9) 7.53%, #5468FC 95.75%)`.
        /// 명함_l 은 각도 112.185°, 시작 알파 0.8 로 **다르다** — 옮겨 쓰지 말 것.
        /// (실측 대비: #728EFD→indigo400 · #5468FC→indigo500 · #444CE7→indigo600)
        static let gradientStart = Color.indigo400.opacity(0.9)
        static let gradientEnd = Color.indigo500

        static let gradientStartLocation: Double = 0.0753
        static let gradientEndLocation: Double = 0.9575

        /// 중앙 방사형 오버레이. 시안은 세로로 눌린 타원이라 축 비율만 옮긴다.
        static let overlayEnd = Color.indigo600.opacity(0.7)
    }

    /// 126.738° 선형 그라데이션을 370×112 상자의 UnitPoint 로 옮긴 값.
    ///
    /// CSS 각도는 «위쪽 = 0°, 시계방향» 이라 화면 좌표(y 아래) 방향은
    /// `(sin θ, -cos θ)` = `(0.8018, 0.5976)`. 선 길이 `|W·sinθ| + |H·cosθ|`
    /// = 370(0.8016) + 112(0.5979) = 363.5pt. 그 절반(181.8)을 중심에서 양쪽으로 밀면
    /// 점 단위 오프셋 `(145.7, 108.7)` 이고, 축마다 W·H 로 나누면 `(0.3938, 0.9705)` 다.
    /// 세로 오프셋이 1 을 넘나드는 건 카드가 납작해서다 — 잘못된 값이 아니다.
    private enum GradientAxis {
        static let start = UnitPoint(x: 0.1062, y: -0.4705)
        static let end = UnitPoint(x: 0.8938, y: 1.4705)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Metrics.blockSpacing) {
            RemoteImage(
                urlString: card.avatarURL ?? "",
                size: CGSize(width: Metrics.avatarSize, height: Metrics.avatarSize)
            )

            VStack(alignment: .leading, spacing: Metrics.blockSpacing) {
                nameRow
                chipRow
            }

            Spacer(minLength: .zero)
        }
        .padding(Metrics.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Metrics.minHeight)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        // 아바타·이름·학교·칩 2개가 따로 읽히면 누구 명함인지 조립해야 알 수 있다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// 「홍길동/길동, ○○대학교, iOS 파트, 12기」.
    private var accessibilityLabel: String {
        [
            card.nameWithNickname,
            card.university,
            "\(card.partDisplayName) 파트",
            "\(card.generation)기",
        ].joined(separator: ", ")
    }

    // MARK: - View Component

    private var nameRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.nameSpacing) {
            // 시안은 Pretendard Bold 지만 `AppFontWeight` 에 bold 가 없다(regular/medium/
            // semibold 3종). 가장 가까운 semibold 를 쓴다 — 명함_l 도 같은 처리를 했다.
            // 확장은 `Pretendard-Bold.otf` 반입이 선행되어야 한다 (#1237).
            //
            // 표기 규칙은 ``MyCard/nameWithNickname`` 한 곳에 있다 — 명함_l·_m·_s
            // 공통이고 원출처는 명함_s 시안(`12657:35806`)이다.
            // 둘 다 `lineLimit(1)` 이라 폭이 모자라면 어느 쪽이 잘릴지 규칙이 없었다.
            // 이름이 1차 식별자라 학교가 먼저 말줄임되게 못 박는다 (#1236).
            Text(card.nameWithNickname)
                .appFont(.title2, weight: .semibold, color: Color.white)
                .lineLimit(1)
                .layoutPriority(1)

            Text(card.university)
                .appFont(.subheadline, color: Color.white)
                .lineLimit(1)
        }
    }

    private var chipRow: some View {
        HStack(spacing: Metrics.chipSpacing) {
            PartChip(text: card.partDisplayName, size: .cardMedium)
            PartChip(text: "\(card.generation)기", size: .cardMedium)
        }
    }

    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: Palette.gradientStart, location: Palette.gradientStartLocation),
                .init(color: Palette.gradientEnd, location: Palette.gradientEndLocation),
            ],
            startPoint: GradientAxis.start,
            endPoint: GradientAxis.end
        )
        .overlay {
            EllipticalGradient(
                colors: [Palette.gradientEnd.opacity(.zero), Palette.overlayEnd],
                center: .center,
                startRadiusFraction: .zero,
                endRadiusFraction: 0.5
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("명함_m") {
    VStack(spacing: 16) {
        BusinessCardSummaryView(card: BusinessCardPreviewData.myCard)
    }
    .padding(16)
}
#endif
