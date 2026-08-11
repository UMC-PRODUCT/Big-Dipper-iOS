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
            .overlay(alignment: .bottom) { createThreadPill }
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

    private func threadList(_ threads: [CommunityThread]) -> some View {
        List {
            if !viewModel.pinned.isEmpty {
                Section("고정") {
                    ForEach(viewModel.pinned) { thread in
                        row(thread)
                    }
                }
            }

            Section(viewModel.pinned.isEmpty ? "" : "전체") {
                ForEach(threads) { thread in
                    row(thread)
                        .task { await viewModel.loadNextPageIfNeeded(currentItem: thread) }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    /// 행 + 스와이프. 개설자 전용 `편집` 은 스레드 수정 화면이 후속 PR 이라 넣지 않는다.
    private func row(_ thread: CommunityThread) -> some View {
        Button {
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

    /// 하단 플로팅 생성 필.
    ///
    /// 스레드 생성 화면이 후속 PR 이라 **배치만 하고 비활성**이다. 자리를 미리 잡아 둬야
    /// 생성 기능이 붙을 때 리스트 하단 여백이 흔들리지 않는다.
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
