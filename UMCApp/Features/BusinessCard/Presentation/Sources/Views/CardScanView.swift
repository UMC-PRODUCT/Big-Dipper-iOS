//
//  CardScanView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/28/26.
//

import SwiftUI
import UIKit
import CoreDesignSystem
import CoreDI
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let title = "QR 스캔"
    static let guide = "상대의 명함 QR을 사각형 안에 맞춰 주세요"

    static let deniedTitle = "카메라를 사용할 수 없어요"
    static let deniedDescription = "설정에서 카메라 접근을 허용하면 QR을 스캔할 수 있어요."
    static let deniedImage = "camera.fill"
    static let openSettings = "설정 열기"

    static let unsupportedTitle = "이 기기에서는 스캔할 수 없어요"
    static let unsupportedDescription =
        "QR 스캔은 iPhone XS 이후 기기에서 동작해요. 상대에게 명함 링크를 공유받아 주세요."
    static let unsupportedImage = "iphone.slash"
}

private enum Metrics {
    static let viewfinderSize: CGFloat = 240
    static let viewfinderRadius: CGFloat = 24
    static let viewfinderLineWidth: CGFloat = 2
    static let captionBottomPadding: CGFloat = 48
    static let captionHorizontalPadding: CGFloat = 24
    static let captionVerticalPadding: CGFloat = 12
    static let captionSpacing: CGFloat = 8
    static let dimOpacity: Double = 0.35
}

/// 인앱 QR 스캐너 (#1224) — 명함 받기가 기본 카메라 앱에 기대지 않게 한다.
///
/// 스캔에 성공하면 딥링크와 **같은** 수신 경로(``CardLinkReceiver``)로 넘긴다. 그래서 이
/// 화면은 조회·저장·완료 화면을 알지 못하고, 명함첩 중복 판정·자기 명함 제외 규칙이 QR
/// 카메라 앱 경로와 한 벌로 유지된다.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 셸이 소유한다.
public struct CardScanView: View {

    // MARK: - Property

    @State private var viewModel: CardScanViewModel

    @Environment(\.openURL) private var openURL

    private let container: DIContainer

    // MARK: - Init

    public init(container: DIContainer, viewModel: CardScanViewModel) {
        self.container = container
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        content
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.prepare() }
            // 스캔 결과는 딥링크와 같은 모디파이어가 받는다 — 저장 경로를 하나로 둔다.
            .businessCardLinkReceiver(link: $viewModel.scannedLink, container: container)
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .preparing:
            Progress()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .scanning:
            scanner

        case .denied:
            ContentUnavailableView {
                Label(Constants.deniedTitle, systemImage: Constants.deniedImage)
            } description: {
                Text(Constants.deniedDescription)
            } actions: {
                Button(Constants.openSettings) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    openURL(url)
                }
            }

        case .unsupported:
            ContentUnavailableView(
                Constants.unsupportedTitle,
                systemImage: Constants.unsupportedImage,
                description: Text(Constants.unsupportedDescription)
            )
        }
    }

    private var scanner: some View {
        QRScannerView(onScanned: viewModel.handle(payload:))
            .overlay { viewfinder }
            .overlay(alignment: .bottom) { caption }
            .ignoresSafeArea(edges: .bottom)
    }

    /// 인식 영역 안내. VisionKit 이 실제로는 화면 전체를 보지만, 어디를 비추라는 지시가
    /// 없으면 사용자가 QR 을 화면 가장자리에 두고 안 읽힌다고 판단한다.
    private var viewfinder: some View {
        RoundedRectangle(cornerRadius: Metrics.viewfinderRadius)
            .strokeBorder(Color.white, lineWidth: Metrics.viewfinderLineWidth)
            .frame(width: Metrics.viewfinderSize, height: Metrics.viewfinderSize)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// 안내 문구. 명함이 아닌 QR 을 읽으면 그 사실로 바뀌고, 다음 인식까지 남는다.
    private var caption: some View {
        Text(viewModel.notice ?? Constants.guide)
            .appFont(.subheadline, color: Color.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Metrics.captionHorizontalPadding)
            .padding(.vertical, Metrics.captionVerticalPadding)
            .background(Color.black.opacity(Metrics.dimOpacity), in: Capsule())
            .padding(.horizontal, Metrics.captionSpacing)
            .padding(.bottom, Metrics.captionBottomPadding)
            .animation(.default, value: viewModel.notice)
            // 카메라 화면에서 이 문구가 유일한 피드백이다. 스캔 결과에 따라 문구가
            // 바뀌는데, 그 사실을 알리지 않으면 VoiceOver 사용자는 계속 첫 안내만 듣는다.
            .accessibilityAddTraits(.updatesFrequently)
    }
}
