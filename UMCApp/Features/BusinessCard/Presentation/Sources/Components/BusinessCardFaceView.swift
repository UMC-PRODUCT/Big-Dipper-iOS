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

    private enum Constants {
        static let exchangeIcon = "shareplay"
        static let exchangeTitle = "명함 교환"
        static let qrIcon = "qrcode"
        static let qrTitle = "QR 코드"
        static let qrLabel = "내 명함 QR 코드"
        static let qrUnavailable = "QR 코드를 만들지 못했어요"
        static let flipIcon = "arrow.2.squarepath"
        static let flipToBack = "명함 뒷면 보기"
        static let flipToFront = "명함 앞면 보기"
    }

    /// 시안 실측값 (`Figma 12639:33234` / `12766:98172`).
    private enum Metrics {
        /// 시안 실측 높이. 글자가 커지면 이 값을 **바닥으로** 두고 늘어난다
        /// (고정하면 AX 크기에서 칩·이름이 카드 밖으로 밀린다).
        static let cardMinHeight: CGFloat = 205
        /// 버튼 행(39)과 그 위 간격(24)을 뺀 높이. 액션 없는 카드가 아래를 비우지 않게 한다.
        static let faceOnlyMinHeight: CGFloat = 205 - 24 - 39
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
        static let logoWidth: CGFloat = 47
        static let logoHeight: CGFloat = 15.16
        static let buttonSpacing: CGFloat = 10
        static let buttonMinHeight: CGFloat = 39
        static let buttonRadius: CGFloat = 40
        static let buttonIconSize: CGFloat = 19
        static let linkSpacing: CGFloat = 8
        static let linkIconSize: CGFloat = 18
        static let qrRadius: CGFloat = 6.18
        static let qrBorderWidth: CGFloat = 0.26
    }

    /// 카드 배경 · QR 테두리. 전부 코어 토큰이다 (#1237).
    ///
    /// 시안 실측은 `linear-gradient(112.185deg, rgba(114,142,253,0.8), #5468FC)` ·
    /// 테두리 `#E5E8ED` 였고 그동안 `BusinessCardPalette` 가 그 raw 값을 들고 있었다.
    /// 같은 화면의 버튼이 `Color.indigo500`(#4869F0)을 쓰는 바람에 파랑이 둘로
    /// 갈렸고, raw 값에는 다크 모드 대응이 없었다. 토큰은 Asset Catalog 라 모드별
    /// 값을 스스로 들고 있으므로 명함도 토큰으로 수렴한다.
    /// (실측과의 차: 시작색 #728EFD→#6683FF · 끝색 #5468FC→#4869F0 · 테두리 #E5E8ED→#E7E8EA)
    private enum Palette {
        static let gradientStart = Color.indigo400
        static let gradientEnd = Color.indigo500
        static let qrBorder = Color.grey200
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

    /// 액션이 하나도 없으면 버튼 행을 그리지 않는다 — 받은 명함 상세(#1227)에는
    /// 「명함 교환」·「QR 코드」가 할 일이 없다. 눌러도 아무 일 없는 버튼을 두느니 뺀다.
    private var hasActions: Bool {
        onExchange != nil || onQR != nil
    }

    public var body: some View {
        VStack(spacing: Metrics.blockSpacing) {
            VStack(alignment: .leading, spacing: Metrics.headerSpacing) {
                header
                if isFlipped { backFace } else { frontFace }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasActions { actionButtons }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity)
        .frame(minHeight: hasActions ? Metrics.cardMinHeight : Metrics.faceOnlyMinHeight)
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
                    // 옆의 "Business card" 텍스트가 같은 뜻을 말한다 — 중복 낭독 방지.
                    .accessibilityHidden(true)

                Text("Business card")
                    .appFont(.caption2, color: Color.white)
            }

            Spacer(minLength: Metrics.linkSpacing)

            flipButton
        }
    }

    @ViewBuilder
    private var flipButton: some View {
        if onFlip != nil { flipButtonBody }
    }

    private var flipButtonBody: some View {
        CardGlassCircleButton(
            systemName: Constants.flipIcon,
            label: isFlipped ? Constants.flipToFront : Constants.flipToBack
        ) {
            onFlip?()
        }
    }

    private var frontFace: some View {
        HStack(alignment: .top, spacing: Metrics.contentSpacing) {
            avatar

            VStack(alignment: .leading, spacing: Metrics.contentSpacing) {
                HStack(alignment: .lastTextBaseline, spacing: Metrics.nameSpacing) {
                    Text(card.displayName)
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
        // 아바타·이름·학교·칩 4개가 따로 읽히면 누구 명함인지 조립해야 알 수 있다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.frontFaceAccessibilityLabel)
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
        // QR 은 어느 모드에서도 흰 바탕이어야 인식된다 — 여기만 토큰을 쓰지 않는다.
        .background(Color.white, in: shape)
        .overlay { shape.stroke(Palette.qrBorder, lineWidth: Metrics.qrBorderWidth) }
        .accessibilityElement()
        .accessibilityLabel(qrImage == nil ? Constants.qrUnavailable : Constants.qrLabel)
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
            .accessibilityElement(children: .combine)
        }
    }

    /// 브랜드 SVG 아이콘(에셋 원본이 흰색이라 틴트 없이 크기만 잡는다).
    ///
    /// VoiceOver 에는 숨긴다 — 링크 값 텍스트가 바로 옆에 있어 에셋 이름까지 읽으면
    /// "githubMono, github.com/umc" 처럼 겹쳐 들린다.
    private func brandIcon(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: Metrics.linkIconSize, height: Metrics.linkIconSize)
            .accessibilityHidden(true)
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
            actionButton(
                icon: Constants.exchangeIcon,
                title: Constants.exchangeTitle,
                action: onExchange
            )
            actionButton(icon: Constants.qrIcon, title: Constants.qrTitle, action: onQR)
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
            // 시안 변수 main-color/indigo500 = 코어 토큰. 카드 그라디언트도 같은
            // 토큰으로 수렴해(#1237) 이제 한 화면에 파랑이 하나뿐이다.
            .foregroundStyle(Color.indigo500)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Metrics.buttonMinHeight)
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
