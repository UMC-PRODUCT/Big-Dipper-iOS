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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            header

            switch viewModel.myCard {
            case .idle, .loading:
                ProgressView()
                    .tint(.white)
                    .frame(height: 84)
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
                    .frame(height: 84)
            }

            actionButtons
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.footnote.weight(.semibold))
                    .padding(6)
                    .background(Color.white.opacity(0.25), in: .circle)
            }
            .accessibilityLabel(isShowingBack ? "앞면 보기" : "뒷면 보기")
        }
        .foregroundStyle(.white)
    }

    private func front(_ card: MyCard) -> some View {
        HStack(alignment: .top, spacing: 14) {
            avatar(card)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(card.name)/\(card.nickname)")
                        .font(.title3.bold())
                    Text(card.university)
                        .font(.caption)
                        .opacity(0.85)
                }

                HStack(spacing: 6) {
                    chip(card.part.name)
                    chip("\(card.generation)기")
                }
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func back(_ card: MyCard) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let qrImage = viewModel.qrImage {
                Image(decorative: qrImage, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .padding(4)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay { Text("QR 없음").font(.caption2).foregroundStyle(.white) }
            }

            VStack(alignment: .leading, spacing: 8) {
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
        HStack(spacing: 12) {
            NavigationLink {
                DebugExchangeView(viewModel: viewModel)
            } label: {
                cardButtonLabel(icon: "person.2.wave.2", title: "명함 교환")
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
        .frame(width: 64, height: 64)
        .clipShape(.circle)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.25))
            .clipShape(Capsule())
    }

    /// 값이 없으면 시안대로 자리는 유지하되 비어 있음을 드러낸다 — 서버 미입력과 매핑 누락을 구분하려고.
    private func linkRow(systemImage: String, value: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .frame(width: 16)
            Text(value ?? "—")
                .font(.caption)
                .lineLimit(1)
                .opacity(value == nil ? 0.5 : 1)
        }
    }

    private func cardButtonLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).bold()
        }
        .font(.subheadline)
        .foregroundStyle(Color.blue)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(Color.white)
        .clipShape(Capsule())
    }
}
#endif
