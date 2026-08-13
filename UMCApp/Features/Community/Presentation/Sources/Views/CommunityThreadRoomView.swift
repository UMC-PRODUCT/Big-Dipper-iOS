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
    static let emptyTitle = "아직 대화가 없어요"
    static let emptyDescription = "첫 메시지를 보내 대화를 시작해 보세요."
    /// HIG 최소 탭 타깃.
    static let minimumTapTarget: CGFloat = 44
    static let newMessagePillIconSize: CGFloat = 12
    static let newMessagePillBottomPadding: CGFloat = 12
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
            // 리스트 위에 얹지 않고 위로 밀어낸다. 오버레이로 띄우면 정작 읽으러 온 첫 버블을 가린다.
            if viewModel.isSummaryBannerVisible {
                ThreadSummaryBanner(
                    unreadCount: viewModel.entryUnreadCount,
                    onTap: { viewModel.isSummarySheetPresented = true },
                    onDismiss: { viewModel.dismissSummaryBanner() }
                )
                .transition(.opacity)
            }

            content

            if let notice = viewModel.sendCooldownNotice {
                noticeCapsule(notice)
            }

            // 신고 접수·중복 안내. 확인을 누를 것이 없어 Alert 대신 쿨다운 안내와 같은 자리에
            // 잠깐 띄운다.
            if let notice = viewModel.reportNotice {
                noticeCapsule(notice)
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
        .animation(.default, value: viewModel.reportNotice)
        .animation(.default, value: viewModel.isSummaryBannerVisible)
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
        .sheet(isPresented: $viewModel.isSummarySheetPresented) {
            ThreadSummarySheet(viewModel: viewModel)
        }
        // 대상이 곧 표시 조건이라 `item:` 을 쓴다 — 성공하면 ViewModel 이 대상을 비워 시트가 닫힌다.
        .sheet(item: $viewModel.reportTarget) { _ in
            MessageReportSheet(viewModel: viewModel)
        }
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

    /// 잠깐 떴다 사라지는 안내 문구. 쿨다운과 신고 접수가 같은 모양을 쓴다.
    private func noticeCapsule(_ notice: String) -> some View {
        Text(notice)
            .appFont(.caption1, color: .grey000)
            .padding(.horizontal, DefaultSpacing.spacing12)
            .padding(.vertical, DefaultSpacing.spacing8)
            .background(Color.grey800, in: .capsule)
            .padding(.bottom, DefaultSpacing.spacing8)
            .transition(.opacity)
    }

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
            MessageListSkeleton()

        case .loaded:
            // 컴포저는 이 분기 밖(헤더 존재 여부)에 걸려 있어 빈 방에서도 그대로 살아 있다.
            if viewModel.messages.isEmpty {
                emptyMessages
            } else {
                messageList
            }

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

    /// 메시지 0건 (스펙 #14). 컴포저는 계속 쓸 수 있으므로 여기서는 유도 문구만 낸다.
    private var emptyMessages: some View {
        ContentUnavailableView(
            Constants.emptyTitle,
            systemImage: "bubble.left.and.bubble.right",
            description: Text(Constants.emptyDescription)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `.defaultScrollAnchor(.bottom)` 이 진입 시 최하단 착지와 새 메시지 추종을 둘 다 처리한다.
    /// `ScrollViewReader` 는 플로팅을 눌렀을 때만 쓴다 — 상시로 스크롤을 밀면 사용자가 위를
    /// 읽는 중에도 끌려 내려가 성가시다.
    private var messageList: some View {
        ScrollViewReader { proxy in
            scrollableMessages
                .overlay(alignment: .bottom) { newMessageOverlay(proxy: proxy) }
        }
    }

    /// 플로팅을 담는 층. `animation` 을 스크롤 뷰가 아니라 여기에 걸어 둔다 — 위에 걸면 같은
    /// 순간에 함께 바뀌는 메시지 배열까지 애니메이션 대상이 된다.
    private func newMessageOverlay(proxy: ScrollViewProxy) -> some View {
        ZStack {
            if viewModel.newMessageCount > 0 {
                newMessagePill(proxy: proxy)
                    .padding(.bottom, Constants.newMessagePillBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: viewModel.newMessageCount)
    }

    private var scrollableMessages: some View {
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
                        canReport: viewModel.canReport(message),
                        onRetry: { Task { await viewModel.retry(message) } },
                        onReact: { emoji in
                            Task { await viewModel.toggleReaction(message, emoji: emoji) }
                        },
                        onCopy: { viewModel.copyContent(message) },
                        onDelete: { viewModel.requestDelete(message) },
                        onReport: { viewModel.requestReport(message) }
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
            // 플로팅 카운트는 ViewModel 이 세고, "지금 최하단인가" 는 화면만 안다.
            viewModel.updateNearBottom(isNearBottom)
        }
    }

    /// 위를 읽는 동안 도착한 메시지 안내 (스펙 #35).
    private func newMessagePill(proxy: ScrollViewProxy) -> some View {
        Button {
            scrollToBottom(proxy: proxy)
        } label: {
            HStack(spacing: DefaultSpacing.spacing4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: Constants.newMessagePillIconSize, weight: .semibold))

                Text("새 메시지 \(viewModel.newMessageCount)개")
            }
            .appFont(.caption1, weight: .semibold, color: .grey000)
            .padding(.horizontal, DefaultSpacing.spacing16)
            // 캡슐 자체는 문구 크기로 두고 탭 영역만 44pt 로 넓힌다.
            .frame(minHeight: Constants.minimumTapTarget)
            .background(Color.indigo500, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 메시지 \(viewModel.newMessageCount)개, 최신 메시지로 이동")
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

    /// 최하단으로 내려간다. 마지막 항목이 `LazyVStack` 에서 아직 만들어지지 않았어도
    /// `scrollTo` 가 위치를 잡아 준다.
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessageId = viewModel.messages.last?.id else { return }

        // 누른 순간 이미 최하단으로 가기로 정해졌다. 스크롤이 끝나고 geometry 콜백이 올 때까지
        // 기다리면 그동안 배지가 남아 눌리지 않은 것처럼 보인다.
        viewModel.updateNearBottom(true)
        withAnimation { proxy.scrollTo(lastMessageId, anchor: .bottom) }
    }

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
