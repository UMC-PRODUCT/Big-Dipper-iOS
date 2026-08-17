//
//  ReceivedCardCell.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI
import BusinessCardDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

/// 명함첩 그리드 한 칸 — 시안 `명함_s` (`Figma 12657:35806`).
///
/// 상태를 갖지 않는다. 탭·삭제 같은 동작은 이 셀을 놓는 화면이 붙인다.
struct ReceivedCardCell: View {

    // MARK: - Property

    let card: ReceivedCard

    // MARK: - Constants

    private enum Metrics {
        /// 시안 실측 폭(402pt 화면 기준). 폭은 **고정하지 않는다** — 375pt 기기에서는
        /// `16 + 181 + 8 + 181 + 16 = 402` 가 화면을 넘고, 440pt 에서는 오른쪽이 빈다.
        /// 열을 유동으로 두고 이 값은 그라데이션 축 산출의 기준으로만 남긴다.
        static let referenceWidth: CGFloat = 181
        static let height: CGFloat = 124
        static let cornerRadius: CGFloat = 34
        static let padding: CGFloat = 16
        /// 상단 행(아바타·칩)과 텍스트 블록 사이.
        static let blockSpacing: CGFloat = 8
        static let avatarSize: CGFloat = 40
        static let chipSpacing: CGFloat = 4
        static let chipHeight: CGFloat = 21
        static let chipHorizontalPadding: CGFloat = 6
        static let textSpacing: CGFloat = 4
    }

    private enum Palette {
        /// 시안은 시드 컬러를 이 농도로만 깐다 — 카드는 거의 흰색이고 파트 색은 힌트다.
        static let linearEndAlpha: Double = 0.1
        static let radialEndAlpha: Double = 0.05
        static let chipAlpha: Double = 0.8

        /// 시안 `linear-gradient(108.16deg, rgba(C,0) 7.53%, rgba(C,0.1) 95.75%)` 의 정지점.
        static let linearStart: Double = 0.0753
        static let linearEnd: Double = 0.9575
    }

    /// 시안의 108.16° 선형 그라데이션을 181×124 상자의 UnitPoint 로 옮긴 값.
    ///
    /// CSS 각도는 «위쪽 = 0°, 시계방향» 이라 화면 좌표(y 아래)에서 방향은
    /// `(sin θ, -cos θ)` = `(0.9503, 0.3113)` — 오른쪽 아래로 흐른다.
    /// CSS 그라데이션 선 길이는 `|W·sin θ| + |H·cos θ|` = 210.6pt 이고, 그 절반을
    /// 중심에서 양쪽으로 민 뒤 축마다 W·H 로 나눠 단위 공간에 넣었다.
    ///
    /// - Note: `UnitPoint` 는 축마다 따로 정규화되므로 카드 폭이 시안 실측(181)에서
    ///   벗어나면 각도가 조금씩 틀어진다. 기기 폭 범위(≈163~200pt)에서 생기는 편차는
    ///   최대 농도가 10% 인 이 그라데이션에서는 눈에 띄지 않아 기준값으로 고정한다.
    private enum GradientAxis {
        static let start = UnitPoint(x: -0.0528, y: 0.2356)
        static let end = UnitPoint(x: 1.0528, y: 0.7644)
    }

    // MARK: - Computed Property

    private var seed: Color {
        card.profile.part.seedColor
    }

    /// 시안 더미가 `이름/닉네임` 이라 둘을 함께 싣는다. 명함_s 에는 텍스트 줄이 둘뿐이고
    /// 아래 줄은 학교가 차지해서 닉네임에 자리를 따로 못 준다.
    ///
    /// - Note: 더미가 「이름 또는 닉네임」을 뜻하는 자리표시자일 수도 있다. 디자이너 확인 대기.
    private var displayName: String {
        let nickname = card.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname.isEmpty ? card.profile.name : "\(card.profile.name)/\(nickname)"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.blockSpacing) {
            header
            textBlock
            // 시안 콘텐츠(40 + 8 + 44 = 92)가 안쪽 높이에 딱 맞아 보통은 0이다.
            // 텍스트가 짧아졌을 때 블록이 세로 중앙으로 떠오르는 것만 막는다.
            Spacer(minLength: .zero)
        }
        .padding(Metrics.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.height)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
    }

    // MARK: - View Component

    private var header: some View {
        HStack(alignment: .top, spacing: .zero) {
            RemoteImage(
                urlString: card.profile.avatarURL ?? "",
                size: CGSize(width: Metrics.avatarSize, height: Metrics.avatarSize)
            )

            Spacer(minLength: .zero)

            HStack(spacing: Metrics.chipSpacing) {
                chip(card.profile.partDisplayName)
                chip("\(card.profile.generation)기")
            }
        }
        .frame(height: Metrics.avatarSize)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Metrics.textSpacing) {
            Text(displayName)
                .appFont(.body, weight: .semibold, color: .grey900)
                .lineLimit(1)

            Text(card.profile.university)
                .appFont(.footnote, color: .grey500)
                .lineLimit(1)
        }
    }

    /// 파트 칩과 기수 칩이 같은 배경을 쓴다 — 시안에 둘 사이 색 구분이 없다.
    ///
    /// - Note: 라벨이 전 파트 공통 흰색이라 Node.js(#FFCC00)에서는 대비가 낮다.
    ///   시안이 그렇게 그려져 있어 그대로 따르되 디자이너 확인이 필요하다.
    private func chip(_ text: String) -> some View {
        Text(text)
            .appFont(.caption2, color: Color.white)
            .lineLimit(1)
            .padding(.horizontal, Metrics.chipHorizontalPadding)
            .frame(height: Metrics.chipHeight)
            .background(seed.opacity(Palette.chipAlpha), in: Capsule())
    }

    /// 시드 컬러 2겹 — 좌상단은 거의 흰색, 우하단으로 갈수록 파트 색이 옅게 깔린다.
    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: seed.opacity(.zero), location: Palette.linearStart),
                .init(color: seed.opacity(Palette.linearEndAlpha), location: Palette.linearEnd),
            ],
            startPoint: GradientAxis.start,
            endPoint: GradientAxis.end
        )
        .overlay {
            // 카드 정중앙을 중심으로 카드 전체를 덮는 타원. 가장자리로 갈수록 진해진다.
            EllipticalGradient(
                colors: [seed.opacity(.zero), seed.opacity(Palette.radialEndAlpha)],
                center: .center,
                startRadiusFraction: .zero,
                endRadiusFraction: 0.5
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("파트별 명함_s") {
    let parts: [UMCPartType] = [
        .admin, .design, .pm, .front(type: .web),
        .front(type: .android), .front(type: .ios),
        .server(type: .spring), .server(type: .node),
    ]

    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(spacing: 8), count: 2), spacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                ReceivedCardCell(card: .preview(part: part))
            }
        }
        .padding(16)
    }
}

private extension ReceivedCard {
    static func preview(part: UMCPartType) -> ReceivedCard {
        ReceivedCard(
            id: part.apiValue,
            profile: MyCard(
                memberId: part.apiValue, name: "이름", nickname: "닉네임",
                part: part, generation: "10", university: "oo대학교",
                email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
            ),
            exchangedAt: Date(timeIntervalSince1970: .zero),
            exchangeContext: nil
        )
    }
}
#endif
