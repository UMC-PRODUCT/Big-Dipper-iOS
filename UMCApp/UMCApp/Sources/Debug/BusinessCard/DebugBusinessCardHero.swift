//
//  DebugBusinessCardHero.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import SwiftUI
import BusinessCardDomain
import UMCFoundation

/// 시안 `명함_l`(372×205) 자리의 명함 카드.
///
/// 앞면은 아바타·이름/닉네임·학교·파트/기수 칩, 뒷면은 QR과 외부 링크 3줄(github ·
/// linkedIn · blog)이다. 우상단 버튼으로 뒤집는다. 하단 「명함 교환」·「QR 코드」 두 버튼도
/// 시안대로 카드 안에 있다.
///
/// 색·타이포는 시안 토큰이 아니다 — 맞추는 것은 **배치**다.
struct DebugBusinessCardHero: View {

    // MARK: - Property

    let container: DIContainer
    let viewModel: BusinessCardDebugViewModel

    @State private var isShowingBack = false

    /// 시안 `명함_l`(I12639:33234) 실측값. 카드 372×205, padding 16.
    private enum Metrics {
        static let cardHeight: CGFloat = 205
        static let cardRadius: CGFloat = 34
        static let cardPadding: CGFloat = 16
        /// 정보 블록과 버튼 행 사이.
        static let blockSpacing: CGFloat = 24
        /// 헤더 행과 그 아래 정보 사이.
        static let headerSpacing: CGFloat = 8
        static let avatarSize: CGFloat = 70
        /// 아바타와 텍스트 블록 사이 · 이름 행과 칩 행 사이 — 시안은 둘 다 16.
        static let contentSpacing: CGFloat = 16
        static let chipSpacing: CGFloat = 5
        static let chipHeight: CGFloat = 23
        static let chipRadius: CGFloat = 24
        static let flipButtonSize: CGFloat = 32
        static let buttonSpacing: CGFloat = 10
        static let buttonHeight: CGFloat = 39
        static let buttonRadius: CGFloat = 40
        static let linkSpacing: CGFloat = 8
        static let linkIconSize: CGFloat = 18
    }

    // MARK: - Body

    var body: some View {
        // 시안 구조: 카드 안 VStack gap 24 { 정보 블록(헤더 + 내용, gap 8), 버튼 행 }.
        VStack(spacing: Metrics.blockSpacing) {
            VStack(alignment: .leading, spacing: Metrics.headerSpacing) {
                header
                cardContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actionButtons
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.cardHeight)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
    }

    @ViewBuilder
    private var cardContent: some View {
        switch viewModel.myCard {
        case .idle, .loading:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.avatarSize)
        case .loaded(let card):
            if isShowingBack {
                back(card)
            } else {
                front(card)
            }
        case .failed(let error):
            Text("명함 로드 실패: \(error.localizedDescription)")
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(height: Metrics.avatarSize)
        }
    }

    // MARK: - Front / Back

    private var header: some View {
        HStack {
            Text("UMC")
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text("Business card")
                .font(.caption)
            Spacer()
            Button {
                withAnimation(.snappy) { isShowingBack.toggle() }
            } label: {
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 15))
                    .frame(width: Metrics.flipButtonSize, height: Metrics.flipButtonSize)
                    .background(Color.white.opacity(0.25), in: .circle)
            }
            .accessibilityLabel(isShowingBack ? "앞면 보기" : "뒷면 보기")
        }
        .foregroundStyle(.white)
    }

    private func front(_ card: MyCard) -> some View {
        HStack(alignment: .top, spacing: Metrics.contentSpacing) {
            avatar(card)

            VStack(alignment: .leading, spacing: Metrics.contentSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.linkSpacing) {
                    Text("\(card.name)/\(card.nickname)")
                        .font(.title3.bold())
                    Text(card.university)
                        .font(.footnote)
                        .opacity(0.85)
                }

                HStack(spacing: Metrics.chipSpacing) {
                    chip(card.part.name)
                    chip("\(card.generation)기")
                }
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 시안 12766:98167 — 뒷면은 **아바타 자리에 QR**이 오고 이름·칩 자리에 링크 3줄이 온다.
    private func back(_ card: MyCard) -> some View {
        HStack(alignment: .top, spacing: Metrics.contentSpacing) {
            if let qrImage = viewModel.qrImage {
                Image(decorative: qrImage, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
                    .overlay { Text("QR 없음").font(.caption2).foregroundStyle(.white) }
            }

            VStack(alignment: .leading, spacing: Metrics.linkSpacing) {
                linkRow(systemImage: "chevron.left.forwardslash.chevron.right", value: card.github)
                linkRow(systemImage: "person.crop.square.filled.and.at.rectangle", value: card.linkedIn)
                linkRow(systemImage: "link", value: card.blog)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        HStack(spacing: Metrics.buttonSpacing) {
            NavigationLink {
                DebugExchangeView(viewModel: viewModel)
            } label: {
                cardButtonLabel(icon: "shareplay", title: "명함 교환")
            }

            NavigationLink {
                DebugQRCodeView(viewModel: viewModel)
            } label: {
                cardButtonLabel(icon: "qrcode", title: "QR 코드")
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Function

    private func avatar(_ card: MyCard) -> some View {
        Group {
            if let avatarURL = card.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.25)
                }
            } else {
                Color.black.opacity(0.7)
                    .overlay {
                        Text("UMC").font(.caption2.bold()).foregroundStyle(.white)
                    }
            }
        }
        .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
        .clipShape(.circle)
    }

    /// 시안 39×23 · radius 24. 폭은 라벨에 맡기되 최소 39는 확보한다 — 「PM」처럼 짧은
    /// 파트명이 시안보다 좁아지면 칩 두 개의 리듬이 깨진다.
    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .frame(minWidth: 39)
            .frame(height: Metrics.chipHeight)
            .background(Color.white.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.chipRadius))
    }

    /// 값이 없으면 시안대로 자리는 유지하되 비어 있음을 드러낸다 — 서버 미입력과 매핑 누락을 구분하려고.
    private func linkRow(systemImage: String, value: String?) -> some View {
        HStack(spacing: Metrics.linkSpacing) {
            Image(systemName: systemImage)
                .font(.footnote)
                .frame(width: Metrics.linkIconSize, height: Metrics.linkIconSize)
            Text(value ?? "—")
                .font(.footnote)
                .lineLimit(1)
                .opacity(value == nil ? 0.5 : 1)
        }
    }

    /// 시안 165×39 · radius 40 — 두 버튼이 카드 폭을 균등 분할한다.
    private func cardButtonLabel(icon: String, title: String) -> some View {
        HStack(spacing: Metrics.buttonSpacing) {
            Image(systemName: icon)
                .font(.system(size: 19))
            Text(title).fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(Color.blue)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.buttonHeight)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius))
    }
}
#endif
