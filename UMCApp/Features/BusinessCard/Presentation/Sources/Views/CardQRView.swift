//
//  CardQRView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI
import BusinessCardDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let title = "QR 코드"
    static let caption = "QR을 스캔하면 내 명함이 저장돼요"
    static let shareTitle = "공유하기"
    static let saveTitle = "이미지 저장"
    static let sharePreviewTitle = "내 명함 QR"

    static let scanLabel = "QR 스캔"
    static let scanImage = "qrcode.viewfinder"

    static let qrUnavailable = "QR을 만들지 못했어요"
    static let qrUnavailableImage = "qrcode"

    static let failureTitle = "명함을 불러올 수 없어요"
    static let failureDescription = "잠시 후 다시 시도해 주세요."
    static let failureImage = "exclamationmark.triangle"
}

private enum Metrics {
    static let horizontalMargin: CGFloat = 16
    static let topMargin: CGFloat = 30
    /// 시안 세로 스택 gap 40 — [명함_m] → [QR 블록] → [버튼 스택].
    static let sectionSpacing: CGFloat = 40
    static let qrBoxSize: CGFloat = 272
    static let qrBoxRadius: CGFloat = 24
    static let qrBoxBorderWidth: CGFloat = 1
    /// 박스 안쪽 여백. 시안 QR 유효영역 약 204pt = 272 - 34×2.
    static let qrInset: CGFloat = 34
    static let captionSpacing: CGFloat = 16
    static let buttonSpacing: CGFloat = 10
    static let shadowRadius: CGFloat = 16
    static let shadowY: CGFloat = 4
    static let cardSkeletonHeight: CGFloat = 112
    static let cardRadius: CGFloat = 34
    static let skeletonOpacity: Double = 0.35
}

private enum Palette {
    static let qrBoxBorder = BusinessCardPalette.hairline
    /// 시안 그림자 rgba(26,31,51,0.08).
    static let qrBoxShadow = Color(red: 26 / 255, green: 31 / 255, blue: 51 / 255).opacity(0.08)
}

/// 내 명함 QR (MP-F02 뒷면·MP-F04) — 시안 `12639:33027`.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 셸이 소유한다.
public struct CardQRView: View {

    // MARK: - Property

    @State private var viewModel: CardQRViewModel

    // MARK: - Init

    public init(viewModel: CardQRViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        content
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 내 QR 을 보여주다 곧바로 상대 QR 을 받는 흐름이 흔하다 (#1224).
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: BusinessCardDestination.scan) {
                        Image(systemName: Constants.scanImage)
                    }
                    .accessibilityLabel(Constants.scanLabel)
                }
            }
            .alertPrompt(item: $viewModel.alertPrompt)
            .task {
                guard viewModel.card.isIdle else { return }
                await viewModel.load()
            }
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        switch viewModel.card {
        case .idle, .loading:
            skeleton

        case .loaded(let card):
            loaded(card)

        case .failed:
            RetryContentUnavailableView(
                title: Constants.failureTitle,
                systemImage: Constants.failureImage,
                description: Constants.failureDescription,
                isRetrying: false,
                retryAction: { await viewModel.load() }
            )
        }
    }

    private func loaded(_ card: MyCard) -> some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                BusinessCardSummaryView(card: card)
                qrBlock
                buttons
            }
            .padding(.horizontal, Metrics.horizontalMargin)
            .padding(.top, Metrics.topMargin)
        }
    }

    private var qrBlock: some View {
        VStack(spacing: Metrics.captionSpacing) {
            qrBox

            Text(Constants.caption)
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.center)
                .frame(width: Metrics.qrBoxSize)
        }
    }

    private var qrBox: some View {
        ZStack {
            if let qrImage = viewModel.qrImage {
                // QR 은 보간하지 않는다 — 모듈 경계가 흐려지면 인식률이 떨어진다.
                // Glass·블러도 이 위에 올리지 않는다.
                Image(decorative: qrImage, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(Metrics.qrInset)
            } else {
                ContentUnavailableView(
                    Constants.qrUnavailable,
                    systemImage: Constants.qrUnavailableImage
                )
            }
        }
        .frame(width: Metrics.qrBoxSize, height: Metrics.qrBoxSize)
        .background(Color.grey000, in: RoundedRectangle(cornerRadius: Metrics.qrBoxRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.qrBoxRadius)
                .strokeBorder(Palette.qrBoxBorder, lineWidth: Metrics.qrBoxBorderWidth)
        }
        .shadow(color: Palette.qrBoxShadow, radius: Metrics.shadowRadius, y: Metrics.shadowY)
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: Metrics.buttonSpacing) {
            if let qrImage = viewModel.qrImage {
                let shareImage = Image(decorative: qrImage, scale: 1)
                ShareLink(
                    item: shareImage,
                    preview: SharePreview(Constants.sharePreviewTitle, image: shareImage)
                ) {
                    Text(Constants.shareTitle).cardActionLabel(role: .primary)
                }

                CardActionButton(title: Constants.saveTitle, role: .secondary) {
                    Task { await viewModel.saveQRImage() }
                }
            }
        }
    }

    /// 시안에 로딩 상태가 없다. 카드·QR 박스 자리를 같은 치수로 잡아 두면 값이 들어올 때
    /// 레이아웃이 밀리지 않는다.
    private var skeleton: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .fill(Color.grey200.opacity(Metrics.skeletonOpacity))
                .frame(height: Metrics.cardSkeletonHeight)

            RoundedRectangle(cornerRadius: Metrics.qrBoxRadius)
                .fill(Color.grey200.opacity(Metrics.skeletonOpacity))
                .frame(width: Metrics.qrBoxSize, height: Metrics.qrBoxSize)

            Spacer(minLength: .zero)
        }
        .padding(.horizontal, Metrics.horizontalMargin)
        .padding(.top, Metrics.topMargin)
        .allowsHitTesting(false)
    }
}
