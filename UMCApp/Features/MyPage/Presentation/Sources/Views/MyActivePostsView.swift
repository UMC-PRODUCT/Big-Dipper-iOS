//
//  MyActivePostsView.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreUIComponents
import MyPageDomain
import SwiftUI
import UMCFoundation

/// 내 활동(내가 쓴 글 / 댓글 단 글 / 스크랩) 목록 화면.
///
/// 세 목록은 조회 UseCase만 다르고 화면 구성이 같아, 타이틀 메뉴로 종류를 바꾼다.
/// ``MyActivePostsViewModel``은 종류를 `let`으로 고정하므로 전환 시 목록 뷰를 새로 만든다.
///
/// - Important: 자체 `NavigationStack`을 만들지 않는다. 탭별 스택은 상위 탭 셸이 소유한다.
struct MyActivePostsView: View {

    // MARK: - Property

    @State private var logType: MyActiveLogsType

    private let container: DIContainer

    // MARK: - Init

    init(container: DIContainer, logType: MyActiveLogsType) {
        self.container = container
        self._logType = State(initialValue: logType)
    }

    // MARK: - Computed Property

    private var naviTitle: NavigationTitle.MyPage {
        switch logType {
        case .myWritePost:
            return .writtenPosts
        case .myWriteComment:
            return .commentedPosts
        case .myScrapPost:
            return .scrappedPosts
        }
    }

    // MARK: - Body

    var body: some View {
        MyActivePostListView(
            viewModel: MyActivePostsViewModel(
                logType: logType,
                useCaseProvider: container.resolve(MyPageUseCaseProviding.self)
            )
        )
        .id(logType)
        .navigation(naviTitle: naviTitle, displayMode: .inline)
        .umcDefaultBackground()
        .toolbar {
            ToolBarCollection.ToolBarCenterMenu(
                items: MyActiveLogsType.allCases,
                selection: $logType,
                itemLabel: \.rawValue,
                itemIcon: \.icon
            )
        }
    }
}

// MARK: - List

/// 한 가지 활동 종류의 목록. 종류가 바뀌면 `.id`로 통째 교체돼 새 ViewModel과 함께 다시 만들어진다.
private struct MyActivePostListView: View {

    // MARK: - Property

    @State private var viewModel: MyActivePostsViewModel

    // MARK: - Init

    init(viewModel: MyActivePostsViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        content
            .task {
                await viewModel.fetchInitialIfNeeded()
            }
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        switch viewModel.postState {
        case .idle, .loading:
            Progress()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let items):
            if items.isEmpty {
                emptyView
            } else {
                list(items)
            }

        case .failed(let error):
            RetryContentUnavailableView(
                title: "목록을 불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: error.errorDescription ?? "잠시 후 다시 시도해 주세요.",
                isRetrying: viewModel.postState.isLoading,
                retryAction: { await viewModel.refresh() }
            )
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            viewModel.logType.rawValue,
            systemImage: viewModel.logType.icon,
            description: Text("아직 \(viewModel.logType.rawValue)이 없어요.")
        )
    }

    private func list(_ items: [CommunityItemModel]) -> some View {
        List {
            ForEach(items) { item in
                MyActivePostRow(item: item)
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: item)
                    }
            }

            if viewModel.isLoadingMore {
                Progress(size: .small)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refresh()
        }
    }
}
