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
    static let qrUnavailableDescription = "명함 정보는 그대로예요. 다시 만들어 볼까요?"
    static let qrUnavailableImage = "qrcode"
    static let qrRetryTitle = "QR 다시 만들기"

    static let qrAccessibilityLabel = "내 명함 QR 코드"
    static let qrAccessibilityHint = "상대가 이 코드를 스캔하면 내 명함이 저장돼요"

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
    /// 시안 실측은 테두리 `#E5E8ED` · 그림자 `rgba(26,31,51,0.08)` 였다.
    /// raw 값에는 다크 모드 대응이 없어 코어 토큰과 `.black` 알파로 수렴한다 (#1237).
    /// 같은 피처의 ``DiscoveredPeerRow`` · ``ReceivedCardCell`` 그림자와 같은 값이다.
    static let qrBoxBorder = Color.grey200
    static let qrBoxShadow = Color.black.opacity(0.08)
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
        .refreshable { await viewModel.refresh() }
    }

    private var qrBlock: some View {
        VStack(spacing: Metrics.captionSpacing) {
            qrBox

            Text(Constants.caption)
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Metrics.qrBoxSize)
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
                    .accessibilityElement()
                    .accessibilityLabel(Constants.qrAccessibilityLabel)
                    .accessibilityHint(Constants.qrAccessibilityHint)
            } else {
                ContentUnavailableView(
                    Constants.qrUnavailable,
                    systemImage: Constants.qrUnavailableImage,
                    description: Text(Constants.qrUnavailableDescription)
                )
            }
        }
        // QR 은 정사각형이어야 스캔된다 — 가로는 고정한다. 세로만 **최소값**으로 풀어
        // 생성 실패 문구가 큰 글자에서 박스 밖으로 잘리지 않게 한다 (#1234).
        // QR 이 있을 때는 scaledToFit 이 204pt 정사각으로 맞아 높이도 272 그대로다.
        .frame(width: Metrics.qrBoxSize)
        .frame(minHeight: Metrics.qrBoxSize)
        .background(Color.grey000, in: RoundedRectangle(cornerRadius: Metrics.qrBoxRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.qrBoxRadius)
                .strokeBorder(Palette.qrBoxBorder, lineWidth: Metrics.qrBoxBorderWidth)
        }
        .shadow(color: Palette.qrBoxShadow, radius: Metrics.shadowRadius, y: Metrics.shadowY)
    }

    /// QR 생성이 실패하면 공유·저장은 줄 게 없다. 그렇다고 스택을 통째로 비우면
    /// 화면에 남는 동작이 하나도 없어 사용자가 나갔다 들어오는 수밖에 없었다 —
    /// 실패한 단계(인코딩)만 다시 도는 버튼으로 바꾼다 (#1230).
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
            } else {
                CardActionButton(title: Constants.qrRetryTitle, role: .primary) {
                    viewModel.retryQRGeneration()
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
