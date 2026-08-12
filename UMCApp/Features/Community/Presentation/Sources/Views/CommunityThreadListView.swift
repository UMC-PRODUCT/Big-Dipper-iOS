//
//  CommunityThreadListView.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

fileprivate enum Constants {
    static let createPillBottomPadding: CGFloat = 24
    static let searchPrompt = "스레드 검색"
}

/// 커뮤니티 탭 루트 — 스레드 리스트.
///
/// 고정/전체 두 섹션으로 나뉘지만, 검색 중에는 서버가 `pinned` 를 비워 보내 자연히 한 섹션이 된다.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 탭 셸이 소유한다.
struct CommunityThreadListView: View {

    // MARK: - Property

    @State private var viewModel: CommunityThreadListViewModel

    private let onThreadSelected: (CommunityThread) -> Void

    // MARK: - Init

    init(
        viewModel: CommunityThreadListViewModel,
        onThreadSelected: @escaping (CommunityThread) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onThreadSelected = onThreadSelected
    }

    // MARK: - Body

    var body: some View {
        content
            .navigationTitle("커뮤니티")
            .umcDefaultBackground()
            .searchable(text: $viewModel.searchText, prompt: Constants.searchPrompt)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ThreadFilterMenu(selection: $viewModel.filter)
                }
            }
            .safeAreaInset(edge: .bottom) { createThreadPill }
            .alertPrompt(item: $viewModel.alertPrompt)
            .task { await viewModel.load() }
            .task { await viewModel.observeRealtime() }
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let threads):
            if threads.isEmpty && viewModel.pinned.isEmpty {
                emptyView
            } else {
                threadList(threads)
            }

        case .failed(let error):
            RetryContentUnavailableView(
                title: "스레드를 불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.load()
            }
        }
    }

    /// 고정 섹션이 없으면 `전체` 헤더도 없앤다. `Section("")` 은 헤더를 지우는 게 아니라
    /// 빈 헤더를 그려서 리스트 상단에 정체불명의 여백을 남긴다.
    private func threadList(_ threads: [CommunityThread]) -> some View {
        List {
            if viewModel.pinned.isEmpty {
                pagedRows(threads)
            } else {
                Section("고정") {
                    ForEach(viewModel.pinned) { thread in
                        row(thread)
                    }
                }

                Section("전체") {
                    pagedRows(threads)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func pagedRows(_ threads: [CommunityThread]) -> some View {
        ForEach(threads) { thread in
            row(thread)
                .task { await viewModel.loadNextPageIfNeeded(currentItem: thread) }
        }
    }

    /// 행 + 스와이프. 개설자 전용 `편집` 은 스레드 수정 화면이 후속 PR 이라 넣지 않는다.
    private func row(_ thread: CommunityThread) -> some View {
        Button {
            // 리스트 뷰는 방에서 pop 해도 계층을 떠난 적이 없어 `.task` 가 다시 돌지 않는다.
            // 여기서 내리지 않으면 읽고 온 배지가 다음 수동 새로고침까지 남는다.
            viewModel.markThreadRead(threadId: thread.id)
            onThreadSelected(thread)
        } label: {
            ThreadListRow(thread: thread)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                Task { await viewModel.togglePin(thread) }
            } label: {
                Label(
                    thread.isPinned ? "고정 해제" : "고정",
                    systemImage: thread.isPinned ? "pin.slash" : "pin"
                )
            }
            .tint(.orange)

            Button {
                Task { await viewModel.toggleMute(thread) }
            } label: {
                Label(
                    thread.isMuted ? "알림 켜기" : "알림 끄기",
                    systemImage: thread.isMuted ? "bell" : "bell.slash"
                )
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.confirmLeave(thread)
            } label: {
                Label("나가기", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "아직 참여한 스레드가 없어요",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("초대를 받으면 이곳에 표시돼요.")
        )
    }

    /// 하단 생성 필.
    ///
    /// 스레드 생성 화면이 후속 PR 이라 **배치만 하고 비활성**이다. `overlay` 가 아니라
    /// `safeAreaInset` 으로 다는 이유는 필이 차지하는 만큼 리스트 콘텐츠 인셋을 실제로
    /// 확보해야 마지막 행이 필 뒤에 가려지지 않기 때문이다.
    private var createThreadPill: some View {
        Button {
        } label: {
            Label("스레드 생성", systemImage: "plus")
                .appFont(.subheadline, weight: .semibold)
                .padding(.horizontal, DefaultSpacing.spacing24)
                .padding(.vertical, DefaultSpacing.spacing12)
        }
        .buttonStyle(.glass)
        .disabled(true)
        .padding(.bottom, Constants.createPillBottomPadding)
    }
}
