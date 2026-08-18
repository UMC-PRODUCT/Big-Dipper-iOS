//
//  BusinessCardFaceView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/17/26.
//

import BusinessCardDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

/// 시안 `명함_l`(372×205) — 마이페이지 루트가 쓰는 명함 카드.
///
/// 앞면(`Figma 12639:33234`)은 아바타·이름/닉네임·학교·파트/기수 칩,
/// 뒷면(`Figma 12766:98167`)은 **아바타 자리에 QR** 이 오고 그 옆에 외부 링크 3줄
/// (github · linkedIn · blog)이 온다. 헤더와 하단 버튼 두 개는 양면 공통이다.
///
/// 상태를 들지 않는다 — 뒤집힘 여부는 소유자가 가지고 ``isFlipped`` 로 내려준다.
/// QR 도 마찬가지로 생성은 UseCase 의 일이라 완성된 이미지를 받는다.
///
/// - Note: 3D 플립 모션은 이 라운드 범위 밖이다. 두 면을 즉시 전환한다.
public struct BusinessCardFaceView: View {

    // MARK: - Property

    private let card: MyCard
    private let isFlipped: Bool
    private let qrImage: CGImage?
    private let onFlip: (() -> Void)?
    private let onExchange: (() -> Void)?
    private let onQR: (() -> Void)?

    /// 시안 실측값 (`Figma 12639:33234` / `12766:98172`).
    private enum Metrics {
        static let cardHeight: CGFloat = 205
        static let cardRadius: CGFloat = 34
        static let cardPadding: CGFloat = 16
        /// 정보 블록과 버튼 행 사이.
        static let blockSpacing: CGFloat = 24
        /// 헤더 행과 그 아래 본문 사이.
        static let headerSpacing: CGFloat = 8
        /// 아바타(또는 QR)와 오른쪽 텍스트 블록 사이 · 이름 행과 칩 행 사이.
        static let contentSpacing: CGFloat = 16
        static let avatarSize: CGFloat = 70
        static let nameSpacing: CGFloat = 8
        static let chipSpacing: CGFloat = 5
        static let flipButtonSize: CGFloat = 32
        static let flipIconSize: CGFloat = 15
        static let logoWidth: CGFloat = 47
        static let logoHeight: CGFloat = 15.16
        static let buttonSpacing: CGFloat = 10
        static let buttonHeight: CGFloat = 39
        static let buttonRadius: CGFloat = 40
        static let buttonIconSize: CGFloat = 19
        static let linkSpacing: CGFloat = 8
        static let linkIconSize: CGFloat = 18
        static let qrRadius: CGFloat = 6.18
        static let qrBorderWidth: CGFloat = 0.26
    }

    /// 카드 배경. 시안에 대응하는 토큰이 없어 실측 색을 그대로 쓴다
    /// (`linear-gradient(112.185deg, rgba(114,142,253,0.8), #5468FC)`).
    private enum Palette {
        static let gradientStart = BusinessCardPalette.cardGradientStart
        static let gradientEnd = BusinessCardPalette.indigo
        static let qrBorder = BusinessCardPalette.hairline
    }

    // MARK: - Init

    public init(
        card: MyCard,
        isFlipped: Bool = false,
        qrImage: CGImage? = nil,
        onFlip: (() -> Void)? = nil,
        onExchange: (() -> Void)? = nil,
        onQR: (() -> Void)? = nil
    ) {
        self.card = card
        self.isFlipped = isFlipped
        self.qrImage = qrImage
        self.onFlip = onFlip
        self.onExchange = onExchange
        self.onQR = onQR
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: Metrics.blockSpacing) {
            VStack(alignment: .leading, spacing: Metrics.headerSpacing) {
                header
                if isFlipped { backFace } else { frontFace }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actionButtons
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.cardHeight)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
    }

    // MARK: - View Component

    /// 시안은 좌하단→우상단 112.185°다. 372×205 카드에서 대각선은 약 119°라
    /// 눈으로 구분되지 않는 차이 안에 들어온다 — 각도를 직접 계산하지 않는다.
    private var cardBackground: some View {
        LinearGradient(
            colors: [Palette.gradientStart.opacity(0.8), Palette.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: Metrics.linkSpacing) {
                Image.umcWordmark
                    .resizable()
                    .scaledToFit()
                    .frame(width: Metrics.logoWidth, height: Metrics.logoHeight)

                Text("Business card")
                    .appFont(.caption2, color: Color.white)
            }

            Spacer(minLength: Metrics.linkSpacing)

            flipButton
        }
    }

    private var flipButton: some View {
        Button {
            onFlip?()
        } label: {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: Metrics.flipIconSize))
                .foregroundStyle(Color.white)
                .frame(width: Metrics.flipButtonSize, height: Metrics.flipButtonSize)
                .glassEffect(.clear, in: Circle())
        }
        .accessibilityLabel(isFlipped ? "명함 앞면 보기" : "명함 뒷면 보기")
    }

    /// 시안 더미 `이름/닉네임` 규칙 — 닉네임이 비어 있으면 이름만 싣는다
    /// (명함_m·명함_s 와 같은 규칙).
    private var displayName: String {
        let nickname = card.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname.isEmpty ? card.name : "\(card.name)/\(nickname)"
    }

    private var frontFace: some View {
        HStack(alignment: .top, spacing: Metrics.contentSpacing) {
            avatar

            VStack(alignment: .leading, spacing: Metrics.contentSpacing) {
                HStack(alignment: .lastTextBaseline, spacing: Metrics.nameSpacing) {
                    Text(displayName)
                        .appFont(.title3, weight: .semibold, color: Color.white)
                        .lineLimit(1)

                    Text(card.university)
                        .appFont(.footnote, color: Color.white)
                        .lineLimit(1)
                }

                HStack(spacing: Metrics.chipSpacing) {
                    PartChip(text: card.partDisplayName)
                    PartChip(text: "\(card.generation)기")
                }
            }

            Spacer(minLength: 0)
        }
    }

    /// 뒷면은 아바타 자리에 QR 이 오고, 이름·칩 자리에 링크 3줄이 온다.
    private var backFace: some View {
        HStack(alignment: .top, spacing: Metrics.contentSpacing) {
            qrThumbnail

            VStack(alignment: .leading, spacing: Metrics.linkSpacing) {
                // github·linkedIn 은 시안 브랜드 SVG(18×18, 흰색 모노).
                // blog 만 시안도 SF Symbol `link` 다.
                linkRow(value: card.github) { brandIcon(Image.githubMono) }
                linkRow(value: card.linkedIn) { brandIcon(Image.linkedInMono) }
                linkRow(value: card.blog) { symbolIcon("link") }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL = card.avatarURL, !avatarURL.isEmpty {
            RemoteImage(
                urlString: avatarURL,
                size: CGSize(width: Metrics.avatarSize, height: Metrics.avatarSize)
            )
        } else {
            Image.umcDefaultProfile
                .resizable()
                .scaledToFill()
                .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
                .clipShape(.circle)
        }
    }

    /// 시안 70×70 흰 박스 · radius 6.18 · 0.26pt 테두리.
    @ViewBuilder
    private var qrThumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.qrRadius)

        Group {
            if let qrImage {
                Image(decorative: qrImage, scale: 1)
                    // QR 은 확대해도 흐려지면 안 된다 — 보간을 끈다.
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(Metrics.linkSpacing)
            } else {
                Color.clear
            }
        }
        .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
        .background(Color.white, in: shape)
        .overlay { shape.stroke(Palette.qrBorder, lineWidth: Metrics.qrBorderWidth) }
    }

    /// 값이 없어도 줄을 지운다 — 시안이 3줄 고정이지만 빈 줄은 서버 미입력을
    /// 링크가 있는 것처럼 보이게 한다.
    @ViewBuilder
    private func linkRow(
        value: String?,
        @ViewBuilder icon: () -> some View
    ) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .bottom, spacing: Metrics.linkSpacing) {
                icon()

                Text(value)
                    .appFont(.footnote, color: Color.white)
                    .lineLimit(1)
            }
        }
    }

    /// 브랜드 SVG 아이콘(에셋 원본이 흰색이라 틴트 없이 크기만 잡는다).
    private func brandIcon(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: Metrics.linkIconSize, height: Metrics.linkIconSize)
    }

    /// SF Symbol 아이콘 — 브랜드 아이콘과 같은 18×18 틀에 맞춘다.
    private func symbolIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: AppFont.footnote.size))
            .foregroundStyle(Color.white)
            .frame(width: Metrics.linkIconSize, height: Metrics.linkIconSize)
    }

    private var actionButtons: some View {
        HStack(spacing: Metrics.buttonSpacing) {
            actionButton(icon: "shareplay", title: "명함 교환", action: onExchange)
            actionButton(icon: "qrcode", title: "QR 코드", action: onQR)
        }
    }

    /// 시안 165×39 · radius 40 — 두 버튼이 카드 폭을 균등 분할한다.
    private func actionButton(
        icon: String,
        title: String,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: Metrics.buttonSpacing) {
                Image(systemName: icon)
                    .font(.system(size: Metrics.buttonIconSize))

                Text(title)
                    .appFont(.subheadline, weight: .semibold)
            }
            // 시안 변수는 main-color/indigo500 이다. 코드베이스 토큰과 이름이 같아
            // 토큰을 쓴다 (실측 hex 는 #5468FC 로 미세하게 다르다).
            .foregroundStyle(Color.indigo500)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.buttonHeight)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Metrics.buttonRadius))
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("앞면") {
    BusinessCardFaceView(card: BusinessCardPreviewData.myCard)
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
        .background(Color.grey100)
}

#Preview("뒷면") {
    BusinessCardFaceView(card: BusinessCardPreviewData.myCard, isFlipped: true)
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
        .background(Color.grey100)
}
#endif
