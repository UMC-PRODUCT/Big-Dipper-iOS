//
//  CommunityThreadRoomView.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

fileprivate enum Constants {
    /// 이 거리 안쪽이면 "최하단을 보고 있다" 로 본다. 버블 한 줄 높이쯤이라 마지막 메시지가
    /// 화면에 들어온 시점과 대체로 일치한다.
    static let bottomProximity: CGFloat = 44
    static let headerLineSpacing: CGFloat = 2
    static let loadFailureTitle = "대화를 불러오지 못했어요"
}

/// 스레드 채팅방.
///
/// 진입 시 최하단에서 시작하고 위로 당기면 `before` 커서로 이전 페이지를 붙인다.
/// 새 메시지가 도착하면 맨 아래로 따라 내려간다.
struct CommunityThreadRoomView: View {

    // MARK: - Property

    @State private var viewModel: CommunityThreadRoomViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// 최하단 근처를 보고 있는지. `defaultScrollAnchor(.bottom)` 으로 진입 직후는 항상 최하단이고,
    /// 스크롤이 일어나기 전에는 geometry 콜백이 오지 않으므로 초기값이 곧 실제 상태다.
    @State private var isNearBottom = true

    // MARK: - Init

    init(viewModel: CommunityThreadRoomViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            content

            if let notice = viewModel.sendCooldownNotice {
                Text(notice)
                    .appFont(.caption1, color: .grey000)
                    .padding(.horizontal, DefaultSpacing.spacing12)
                    .padding(.vertical, DefaultSpacing.spacing8)
                    .background(Color.grey800, in: .capsule)
                    .padding(.bottom, DefaultSpacing.spacing8)
                    .transition(.opacity)
            }

            // 첫 로드가 끝나기 전이거나 실패했으면 보낼 방이 없다.
            if viewModel.header.value != nil {
                MessageComposer(
                    text: $viewModel.draft,
                    canSend: viewModel.canSend,
                    onSend: { Task { await viewModel.send() } }
                )
            }
        }
        .animation(.default, value: viewModel.sendCooldownNotice)
        .umcDefaultBackground()
        .navigationBarTitleDisplayMode(.inline)
        // 헤더가 오기 전에는 principal 아이템 자체를 만들지 않는다. 내용이 빈 principal 은
        // titleView 를 차지한 채로 비어 있어서, 라우팅이 걸어 둔 `navigationTitle` 까지 가린다.
        .toolbar {
            if let thread = viewModel.header.value {
                ToolbarItem(placement: .principal) { navigationHeader(thread) }
            }
        }
        .task { await viewModel.load() }
        .task { await viewModel.observeRealtime() }
        .alertPrompt(item: $viewModel.alertPrompt)
        // 스펙 6.4: 포그라운드 + 최하단일 때만 워터마크를 올린다. 과거를 읽는 중이거나 앱이
        // 백그라운드인 동안 올리면 안 본 메시지까지 읽음 처리된다.
        .onChange(of: readableMessageId) { _, messageId in
            guard let messageId else { return }
            viewModel.markRead(upTo: messageId)
        }
        // 강퇴·스레드 삭제. 안내를 확인한 뒤에 리스트로 되돌린다 (스펙 §7).
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
        }
    }

    // MARK: - View Component

    private func navigationHeader(_ thread: CommunityThread) -> some View {
        VStack(spacing: Constants.headerLineSpacing) {
            Text(thread.title)
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(Color.grey900)

            Text("\(thread.category.displayName) · \(thread.memberCountText)")
                .appFont(.caption2, color: .grey500)
        }
        .accessibilityElement(children: .combine)
    }

    /// 헤더와 히스토리 첫 페이지는 한 몸이라 상태도 하나다 (Task 16). 실패는 인라인 재시도로
    /// 끝낸다 — `load()` 는 최신 페이지로 리셋하므로 올려다보던 과거는 다시 스크롤해야 한다.
    @ViewBuilder
    private var content: some View {
        switch viewModel.header {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            messageList

        case .failed(let error):
            RetryContentUnavailableView(
                title: Constants.loadFailureTitle,
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.load()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// `.defaultScrollAnchor(.bottom)` 이 진입 시 최하단 착지와 새 메시지 추종을 둘 다 처리한다.
    /// ScrollViewReader 로 직접 스크롤을 밀면 사용자가 위를 읽는 중에도 끌려 내려가 성가시다.
    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoadingOlder {
                    ProgressView()
                        .padding(.vertical, DefaultSpacing.spacing8)
                }

                let indexed = Array(viewModel.messages.enumerated())
                ForEach(indexed, id: \.element.id) { index, message in
                    if let dividerDate = Self.dividerDate(at: index, in: viewModel.messages) {
                        DateDivider(date: dividerDate)
                    }

                    MessageBubble(
                        message: message,
                        isMine: viewModel.isMine(message),
                        canDelete: viewModel.canDelete(message),
                        onRetry: { Task { await viewModel.retry(message) } },
                        onReact: { emoji in
                            Task { await viewModel.toggleReaction(message, emoji: emoji) }
                        },
                        onCopy: { viewModel.copyContent(message) },
                        onDelete: { viewModel.requestDelete(message) }
                    )
                    .task { await viewModel.loadOlderIfNeeded(currentItem: message) }
                }
            }
            .padding(.horizontal, DefaultSpacing.spacing16)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.containerSize.height
                >= geometry.contentSize.height - Constants.bottomProximity
        } action: { _, isNearBottom in
            self.isNearBottom = isNearBottom
        }
    }

    // MARK: - Computed Property

    private var readableMessageId: String? {
        Self.readableMessageId(
            scenePhase: scenePhase,
            isNearBottom: isNearBottom,
            messages: viewModel.messages
        )
    }

    // MARK: - Function

    /// 읽음 워터마크로 올릴 메시지. 게이팅 조건 세 가지(포그라운드·최하단·표시할 메시지 존재)를
    /// 한 값으로 합쳐 두면 어느 것이 바뀌든 `onChange` 한 곳만 반응하면 된다.
    ///
    /// 미확정 버블의 가짜 id 는 ViewModel 이 걸러 내므로 여기서 다시 보지 않는다.
    static func readableMessageId(
        scenePhase: ScenePhase,
        isNearBottom: Bool,
        messages: [ThreadMessage]
    ) -> String? {
        guard scenePhase == .active, isNearBottom else { return nil }
        return messages.last?.id
    }

    /// 앞 메시지와 날짜가 다를 때만 구분선을 넣는다. 첫 메시지 앞에는 항상 넣는다.
    static func dividerDate(at index: Int, in messages: [ThreadMessage]) -> Date? {
        guard messages.indices.contains(index) else { return nil }
        let current = messages[index].createdAt

        guard index > messages.startIndex else { return current }
        let previous = messages[index - 1].createdAt
        return Calendar.current.isDate(previous, inSameDayAs: current) ? nil : current
    }
}
