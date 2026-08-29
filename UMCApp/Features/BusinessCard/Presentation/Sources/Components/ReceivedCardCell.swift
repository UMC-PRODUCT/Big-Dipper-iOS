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
        /// 시안 실측 높이. **바닥값**이다 — 글자가 커지면 칸이 따라 늘어난다.
        static let minHeight: CGFloat = 124
        static let cornerRadius: CGFloat = 34
        static let padding: CGFloat = 16
        /// 상단 행(아바타·칩)과 텍스트 블록 사이.
        static let blockSpacing: CGFloat = 8
        static let avatarSize: CGFloat = 40
        static let chipSpacing: CGFloat = 4
        /// 시안 칩 높이. **바닥값**이다 — 고정하면 큰 글자에서 라벨이 캡슐을 넘는다.
        static let chipMinHeight: CGFloat = 21
        static let chipHorizontalPadding: CGFloat = 6
        static let chipVerticalPadding: CGFloat = 2
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
        .frame(minHeight: Metrics.minHeight)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        // 아바타·칩 2개·이름·학교가 따로 읽히면 한 칸을 훑는 데 다섯 번이 걸린다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// 「홍길동/길동, ○○대학교, iOS 파트, 12기」.
    private var accessibilityLabel: String {
        [
            displayName,
            card.profile.university,
            "\(card.profile.partDisplayName) 파트",
            "\(card.profile.generation)기",
        ].joined(separator: ", ")
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
        .frame(minHeight: Metrics.avatarSize)
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
    /// - Important: **흰 라벨이 WCAG AA(4.5:1)를 8개 파트 전부 미달한다** (#1235).
    ///   시드@0.8 을 카드 면(틴트 최대 0.15)에 합성한 라이트 모드 실측 대비비:
    ///   Admin 3.75 · PM 3.40 · Design 3.15 · Web 2.74 · Spring 1.96 · Android 1.94 ·
    ///   iOS 1.94 · **Node 1.42** (최악). 같은 배경에 검정 라벨을 얹으면
    ///   5.60~14.77 로 8개 전부 통과한다.
    ///   색 선택은 디자인 결정이라 여기서 바꾸지 않는다 — #1236 시안 확정 대기.
    private func chip(_ text: String) -> some View {
        Text(text)
            .appFont(.caption2, color: Color.white)
            .lineLimit(1)
            .padding(.horizontal, Metrics.chipHorizontalPadding)
            .padding(.vertical, Metrics.chipVerticalPadding)
            .frame(minHeight: Metrics.chipMinHeight)
            .background(seed.opacity(Palette.chipAlpha), in: Capsule())
    }

    /// 시드 컬러 2겹 — 좌상단은 거의 흰색, 우하단으로 갈수록 파트 색이 옅게 깔린다.
    ///
    /// 시드는 알파 0.05~0.1 뿐이라 **그 자체로는 면이 되지 못한다.** 라이트에서는
    /// 흰 배경이 대신 면 노릇을 해 왔지만 다크에서는 카드가 배경에 녹아 사라진다.
    /// `grey000`(라이트 흰색 / 다크 검정)을 바닥에 깔아 어느 모드에서도 면이 남게 한다.
    /// 같은 피처의 ``DiscoveredPeerRow`` 가 쓰는 카드 면과 같은 토큰이다.
    private var background: some View {
        Color.grey000.overlay {
            seedTint
        }
    }

    private var seedTint: some View {
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
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(spacing: 8), count: 2), spacing: 8) {
            ForEach(BusinessCardPreviewData.receivedCards) { card in
                ReceivedCardCell(card: card)
            }
        }
        .padding(16)
    }
}
#endif
