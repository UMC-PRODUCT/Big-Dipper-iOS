//
//  ReceivedCardsView.swift
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
    static let title = "받은 명함"
    static let searchPrompt = "이름, 파트 검색"

    static let emptyTitle = "아직 받은 명함이 없어요"
    static let emptyDescription = "가까이 있는 멤버와 명함을 교환하면 여기에 모여요."
    static let emptyImage = "person.crop.rectangle.stack"

    static let failureTitle = "명함첩을 열 수 없어요"
    static let failureDescription = "잠시 후 다시 시도해 주세요."
    static let failureImage = "exclamationmark.triangle"

    static let deleteLabel = "삭제"
    static let deleteImage = "trash"

    static let openHint = "이 명함을 자세히 봅니다"

    /// 스켈레톤 칸 수. 첫 화면에 그리드가 찬 느낌만 주면 되므로 한 화면 분량으로 둔다.
    static let skeletonCount = 6
}

private enum Metrics {
    static let columnCount = 2
    static let gridSpacing: CGFloat = 8
    static let horizontalMargin: CGFloat = 16
    static let topMargin: CGFloat = 16
    static let cardHeight: CGFloat = 124
    static let cardRadius: CGFloat = 34
    static let skeletonOpacity: Double = 0.35
}

/// 명함첩 (MP-F05) — 시안 `12639:33678`(목록) / `12640:35886`(검색).
///
/// 두 시안은 같은 2열 그리드에 상단 바만 다르다. 돋보기 버튼이 눌리면 검색 필드가
/// 내비게이션 바 자리를 차지하는데, 그게 `.searchToolbarBehavior(.minimize)` 의
/// 기본 동작이라 화면을 둘로 나누지 않고 하나로 둔다.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 셸이 소유한다.
public struct ReceivedCardsView: View {

    // MARK: - Property

    @State private var viewModel: ReceivedCardsViewModel

    // MARK: - Init

    public init(viewModel: ReceivedCardsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        content
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: Constants.searchPrompt)
            .searchToolbarBehavior(.minimize)
            .alertPrompt(item: $viewModel.alertPrompt)
            .task {
                guard viewModel.cards.isIdle else { return }
                await viewModel.load()
            }
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        switch viewModel.cards {
        case .idle, .loading:
            skeleton

        case .loaded(let cards) where cards.isEmpty:
            emptyState

        case .loaded(let cards):
            grid { ForEach(cards) { card in cell(card) } }

        case .failed:
            // 여기서는 정의상 로딩 중이 아니다 — 재시도하면 위 `.loading` 가지로 넘어가
            // 스켈레톤이 대신 뜬다.
            RetryContentUnavailableView(
                title: Constants.failureTitle,
                systemImage: Constants.failureImage,
                description: Constants.failureDescription,
                isRetrying: false,
                retryAction: { await viewModel.load() }
            )
        }
    }

    private func cell(_ card: ReceivedCard) -> some View {
        ReceivedCardCell(card: card)
            .contextMenu {
                // 시안에 삭제 동선이 없다. 그리드는 스와이프를 못 받으므로 길게 눌러
                // 꺼내는 컨텍스트 메뉴로 둔다 — 카드 모양을 건드리지 않는 유일한 자리다.
                Button(role: .destructive) {
                    viewModel.requestDelete(card)
                } label: {
                    Label(Constants.deleteLabel, systemImage: Constants.deleteImage)
                }
            }
            // 길게 누르기만으로는 VoiceOver 사용자가 삭제에 닿지 못한다. 같은 동작을
            // 로터 액션으로도 내보낸다 — 컨텍스트 메뉴와 진입점만 다르고 흐름은 같다.
            .accessibilityAction(named: Constants.deleteLabel) {
                viewModel.requestDelete(card)
            }
    }

    /// 검색 중인지에 따라 빈 화면의 뜻이 다르다 — 「아직 한 장도 없음」과 「이 검색어에
    /// 걸리는 게 없음」을 같은 문구로 덮으면 사용자가 명함첩이 비었다고 오해한다.
    @ViewBuilder
    private var emptyState: some View {
        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView(
                Constants.emptyTitle,
                systemImage: Constants.emptyImage,
                description: Text(Constants.emptyDescription)
            )
        } else {
            ContentUnavailableView.search(text: viewModel.searchText)
        }
    }

    private var skeleton: some View {
        grid {
            ForEach(0..<Constants.skeletonCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .fill(Color.grey200.opacity(Metrics.skeletonOpacity))
                    .frame(height: Metrics.cardHeight)
            }
        }
        .allowsHitTesting(false)
    }

    private func grid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: Metrics.gridSpacing),
                    count: Metrics.columnCount
                ),
                spacing: Metrics.gridSpacing
            ) {
                content()
            }
            .padding(.horizontal, Metrics.horizontalMargin)
            .padding(.top, Metrics.topMargin)
        }
        .refreshable { await viewModel.refresh() }
    }
}
