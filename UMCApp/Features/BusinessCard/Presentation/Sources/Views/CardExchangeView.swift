//
//  CardExchangeView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI
import BusinessCardDomain
import CoreDesignSystem
import CoreNearbyExchange
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let title = "명함 교환"
    static let stopTitle = "교환 중지"

    static let openSettings = "설정 열기"
    static let retry = "다시 시도"
    static let searchAgain = "다시 찾기"

    static let cardFailureTitle = "내 명함을 불러올 수 없어요"
    static let cardFailureDescription = "명함이 있어야 상대에게 보낼 수 있어요."
    static let cardFailureImage = "exclamationmark.triangle"
}

private enum Metrics {
    static let horizontalMargin: CGFloat = 16
    static let topMargin: CGFloat = 16
    static let rowSpacing: CGFloat = 8
    static let bottomMargin: CGFloat = 16
}

/// 근거리 명함 교환 (시안 목록 `12654:32621` · 탐색 중 `12654:32255`).
///
/// 행을 누르면 그 상대에게 내 명함을 보낸다. 상대 명함이 도착하면 완료 화면이 덮는다 —
/// 시안의 완료 화면에 뒤로가기가 없어 모달 전제다.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 셸이 소유한다.
public struct CardExchangeView: View {

    // MARK: - Property

    @State private var viewModel: CardExchangeViewModel

    // MARK: - Init

    public init(viewModel: CardExchangeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: .zero) {
            content

            CardActionButton(title: Constants.stopTitle, role: .destructive) {
                Task { await viewModel.stop() }
            }
            .padding(.horizontal, Metrics.horizontalMargin)
            .padding(.bottom, Metrics.bottomMargin)
        }
        .navigationTitle(Constants.title)
        .navigationBarTitleDisplayMode(.inline)
        // 세션 수명 = 화면 수명. `start()` 는 스트림이 닫힐 때까지 돌아오지 않으므로
        // `.task` 가 화면 이탈 시 취소해 준다. 광고 중지는 `stop()` 이 따로 맡는다.
        .task {
            await viewModel.start()
        }
        .onDisappear {
            Task { await viewModel.stop() }
        }
        .fullScreenCover(item: Binding(
            get: { viewModel.completedCard },
            set: { if $0 == nil { viewModel.dismissCompletion() } }
        )) { card in
            ExchangeCompletedView(
                card: card,
                onContinue: {
                    viewModel.dismissCompletion()
                    Task { await viewModel.start() }
                },
                onFinish: { viewModel.dismissCompletion() }
            )
        }
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        if viewModel.myCard.error != nil {
            ContentUnavailableView(
                Constants.cardFailureTitle,
                systemImage: Constants.cardFailureImage,
                description: Text(Constants.cardFailureDescription)
            )
        } else if let failure = viewModel.failure {
            failureView(failure)
        } else if viewModel.peers.isEmpty {
            // 시안 12654:32255 — 아직 아무도 발견하지 못한 동안의 레이더 화면.
            ScrollView {
                ExchangeSearchingView(avatarURL: viewModel.myCard.value?.avatarURL)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            peerList
        }
    }

    /// 사유별로 문구와 복구 버튼이 다르다 — 만료된 사용자에게 권한을 켜라고 하면
    /// 켤 것이 없어 사용자는 막힌다.
    private func failureView(_ failure: BusinessCardError) -> some View {
        let style = FailureStyle(failure)

        return ContentUnavailableView {
            Label(style.title, systemImage: style.image)
        } description: {
            Text(failure.errorDescription ?? "")
        } actions: {
            Button(style.actionTitle) {
                if style.opensSettings {
                    openAppSettings()
                } else {
                    Task { await viewModel.start() }
                }
            }
        }
    }

    private var peerList: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.rowSpacing) {
                ForEach(viewModel.peers) { peer in
                    Button {
                        Task { await viewModel.send(to: peer) }
                    } label: {
                        DiscoveredPeerRow(peer: peer)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.horizontalMargin)
            .padding(.top, Metrics.topMargin)
        }
    }

}

// MARK: - Failure Style

/// 실패 사유 → 화면 표현. 사유마다 제목·아이콘·복구 버튼이 다르다.
///
/// 케이스별 `switch` 를 항목 수만큼 늘어놓으면 한 사유의 문구를 고칠 때 나머지를
/// 빼먹는다. 한 자리에서 한 번에 고른다.
private struct FailureStyle {

    let title: String
    let image: String
    let actionTitle: String
    /// 권한은 앱 안에서 풀 수 없다 — 설정을 여는 것 말고 할 수 있는 게 없다.
    let opensSettings: Bool

    init(_ failure: BusinessCardError) {
        switch failure {
        case .permissionDenied:
            title = "교환을 시작할 수 없어요"
            image = "wifi.exclamationmark"
            actionTitle = Constants.openSettings
            opensSettings = true
        case .sessionExpired:
            title = "교환을 멈췄어요"
            image = "clock.badge.exclamationmark"
            actionTitle = Constants.searchAgain
            opensSettings = false
        case .exchangeFailed:
            title = "주변 기기와 연결하지 못했어요"
            image = "antenna.radiowaves.left.and.right.slash"
            actionTitle = Constants.retry
            opensSettings = false
        case .saveFailed:
            title = "명함을 저장하지 못했어요"
            image = "externaldrive.badge.exclamationmark"
            actionTitle = Constants.retry
            opensSettings = false
        case .invalidCardLink:
            title = "명함 정보를 읽을 수 없어요"
            image = "exclamationmark.triangle"
            actionTitle = Constants.retry
            opensSettings = false
        }
    }
}

private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
}
