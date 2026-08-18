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

    static let searchingTitle = "주변 멤버를 찾고 있어요"
    static let searchingDescription = "상대도 「명함 교환」을 열어야 서로 보입니다."

    static let failedTitle = "교환을 시작할 수 없어요"
    static let failedDescription = "블루투스와 로컬 네트워크 권한을 확인해 주세요."
    static let failedImage = "antenna.radiowaves.left.and.right.slash"

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

/// 근거리 명함 교환 (시안 `12654:32621`).
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
        } else if viewModel.sessionFailed {
            ContentUnavailableView(
                Constants.failedTitle,
                systemImage: Constants.failedImage,
                description: Text(Constants.failedDescription)
            )
        } else if viewModel.peers.isEmpty {
            searching
        } else {
            peerList
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

    /// 시안에 빈 상태가 없다. 목록이 비어 있는 동안 화면이 완전히 비면 사용자는 앱이
    /// 멈춘 걸로 읽는다 — 찾는 중이라는 것과, 상대도 화면을 열어야 한다는 걸 알린다.
    private var searching: some View {
        ContentUnavailableView {
            Label {
                Text(Constants.searchingTitle)
            } icon: {
                ProgressView()
            }
        } description: {
            Text(Constants.searchingDescription)
        }
    }
}
