//
//  CommunityDetailView.swift
//  AppProduct
//
//  Created by 김미주 on 1/19/26.
//

import SwiftUI

/// 커뮤니티 게시글 상세 화면
///
/// 게시글 상세 정보, 댓글 목록, 좋아요/스크랩 기능을 제공합니다.
/// 본인 게시글인 경우 수정/삭제, 타인 게시글인 경우 신고 기능이 툴바에 표시됩니다.
struct CommunityDetailView: View {
    // MARK: - Property

    @State private var vm: CommunityDetailViewModel
    @State private var isCommentInputExpanded: Bool = false
    @State private var isCommentInputHidden: Bool = true
    @State private var showGuestToast: Bool = false
    @FocusState private var isCommentFieldFocused: Bool
    @Environment(\.di) private var di
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFlow) private var appFlow
    @Environment(\.appSessionMode) private var sessionMode
    @Environment(ErrorHandler.self) var errorHandler

    /// 커뮤니티 상세에서 사용하는 내비게이션 경로 저장소입니다.
    ///
    /// 상세 화면에서 수정 화면으로 이동하거나, 삭제 후 목록 스택을 조정할 때
    /// `DIContainer`를 통해 주입된 `PathStore`를 사용합니다.
    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    private enum Constant {
        static let mainPadding: EdgeInsets = .init(top: 0, leading: 16, bottom: 0, trailing: 16)
        static let postSectionSpacing: CGFloat = DefaultSpacing.spacing12
        static let contentSectionSpacing: CGFloat = DefaultSpacing.spacing32
        static let commentsSectionSpacing: CGFloat = DefaultSpacing.spacing16
        static let commentInputActionRowSpacing: CGFloat = DefaultSpacing.spacing8
        static let textFieldMinHeight: CGFloat = 36
        static let textFieldPadding: EdgeInsets = .init(top: 0, leading: 16, bottom: 0, trailing: 16)
        static let sendButtonSize: CGSize = .init(width: 42, height: 42)
        static let commentLoadingMessage: String = "댓글을 불러오는 중입니다..."
        static let commentsCountTitle: String = "댓글 %d개"
        static let commentLoadFailedTitle: String = "댓글을 불러오지 못했어요"
        static let commentLoadFailedDescription: String = "댓글을 불러오지 못했습니다.\n잠시 후 다시 시도해주세요."
        static let collapsedButtonSize: CGFloat = 58
        static let inputHorizontalPadding: CGFloat = 26
        static let inputBottomOffset: CGFloat = 10
        static let commentInputAnimation: Animation = .easeInOut(duration: 0.2)
        static let commentSectionBottomSpacing: CGFloat = 6
        static let commentInputBottomPadding: CGFloat = 6
        static let collapsedButtonFontSize: CGFloat = 22
        static let commentTextFieldHorizontalPadding: CGFloat = 14
        static let commentTextFieldVerticalPadding: CGFloat = 10
        static let commentTextLineLimit: ClosedRange<Int> = 1...4
        static let commentPrompt: String = "댓글 추가"
        static let sendButtonIconSize: CGFloat = 17
        static let inputSectionSpacing: CGFloat = 24
        static let sendButtonActiveColor: Color = .indigo500
        static let sendButtonDisabledColor: Color = .grey200
        /// 실패 상태 문구
        static let failedTitle: String = "불러오지 못했어요"
        static let failedSystemImage: String = "exclamationmark.triangle"
        static let failedDescription: String = "게시글을 불러오지 못했습니다.\n잠시 후 다시 시도해주세요."
        static let unavailableTitle: String = "게시글을 확인할 수 없어요"
        static let unavailableDescription: String = "삭제되었거나 작성자 정보를 확인할 수 없어\n이 게시글을 표시할 수 없습니다."
        static let unavailableActionTitle: String = "목록으로 돌아가기"
        /// 재시도 버튼 문구/크기
        static let retryTitle: String = "다시 시도"
        static let retryMinimumWidth: CGFloat = 72
        static let retryMinimumHeight: CGFloat = 20
        /// 로딩 문구
        static let loadingMessage: String = "게시글을 불러오는 중입니다..."
    }

    // MARK: - Initializer

    /// 게시글 식별자에 해당하는 상세 화면을 구성합니다.
    ///
    /// - Parameters:
    ///   - container: ViewModel과 경로 저장소를 해석하는 의존성 컨테이너입니다.
    ///   - errorHandler: 전역 에러 처리를 담당하는 핸들러입니다.
    ///   - postId: 조회할 게시글의 서버 식별자입니다.
    init(container: DIContainer,
         errorHandler: ErrorHandler,
         postId: Int
    ) {
        let viewModel = CommunityDetailViewModel(
            container: container, errorHandler: errorHandler, postId: postId
        )
        self._vm = .init(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        rootContent
        .navigation(naviTitle: .communityDetail, displayMode: .inline)
        .task {
            await vm.fetchPostDetail()
            await vm.fetchPostPermission()
            await vm.fetchComments()
        }
        .onChange(of: pathStore.communityPath.count) { oldCount, newCount in
            if newCount < oldCount {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초
                    await vm.fetchPostDetail()
                    await vm.fetchPostPermission()
                    await vm.fetchComments()
                }
            }
        }
        .toolbar {
            if let postItem = vm.postItem {
                ToolBarCollection.ToolbarTrailingMenu(actions: toolbarActions(for: postItem))
            }
        }
        .alertPrompt(item: $vm.alertPrompt)
        .onChange(of: vm.didCompleteComment) { _, completed in
            if completed, sessionMode.isGuest {
                showGuestToast = true
            }
            if completed {
                vm.didCompleteComment = false
            }
        }
        .guestActionToast(isPresented: $showGuestToast) {
            appFlow.showLogin()
        }
        .umcDefaultBackground()
    }

    /// 게시글 상세 로딩 상태에 따라 적절한 루트 콘텐츠를 선택합니다.
    ///
    /// 상세 본문이 준비되지 않았을 때는 전체 화면 로딩 또는 실패 UI를 표시하고,
    /// 로드가 완료되면 게시글/댓글 조합 화면으로 전환합니다.
    @ViewBuilder
    private var rootContent: some View {
        switch vm.postDetailState {
        case .idle, .loading:
            Progress(message: Constant.loadingMessage, size: .regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            detailContent()
        case .failed:
            postDetailFailedContent()
        }
    }

    /// 게시글 본문과 댓글 영역을 함께 구성하는 상세 화면의 본체입니다.
    ///
    /// 스크롤 상태에 따라 댓글 입력창을 접거나 펼치며, 하단 safe area에
    /// 댓글 입력 UI를 고정해 상세 읽기 흐름을 유지합니다.
    @ViewBuilder
    private func detailContent() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constant.contentSectionSpacing) {
                postSection
                commentStateSection
            }
            .padding(Constant.mainPadding)
        }
        .onScrollPhaseChange { _, newPhase in handleScrollPhaseChange(newPhase) }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaBar(edge: .bottom, alignment: .trailing, spacing: Constant.inputSectionSpacing) {
            commentInputInset
        }
    }

    // MARK: - Toolbar Actions

    /// 게시글 소유 여부에 맞는 툴바 메뉴 액션을 생성합니다.
    ///
    /// - Parameter postItem: 현재 상세 화면에 표시 중인 게시글 모델입니다.
    /// - Returns: 작성자 본인일 때는 수정/삭제, 타인일 때는 신고 액션 목록입니다.
    private func toolbarActions(for postItem: CommunityItemModel) -> [ToolBarCollection.ToolbarTrailingMenu.ActionItem] {
        var actions: [ToolBarCollection.ToolbarTrailingMenu.ActionItem] = []

        if vm.canEditPost {
            actions.append(.init(title: "수정하기", icon: "pencil") {
                pathStore.communityPath.append(.community(.post(editItem: postItem)))
            })
        }

        if vm.canDeletePost {
            actions.append(.init(title: "삭제하기", icon: "trash", role: .destructive) {
                showDeletePostAlert()
            })
        }

        if !vm.canEditPost && !vm.canDeletePost {
            actions.append(.init(title: "신고하기", icon: "light.beacon.max.fill", role: .destructive) {
                showReportPostAlert()
            })
        }

        return actions
    }

    // MARK: - Alert Functions

    /// 게시글 삭제 확인 Alert
    private func showDeletePostAlert() {
        vm.alertPrompt = AlertPrompt(
            title: "게시글 삭제",
            message: "게시글을 삭제하시겠습니까?",
            positiveBtnTitle: "삭제",
            positiveBtnAction: {
                Task {
                    await vm.deletePost()
                }
                pathStore.communityPath.removeLast()
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 게시글 신고 확인 Alert
    private func showReportPostAlert() {
        vm.alertPrompt = AlertPrompt(
            title: "게시글 신고",
            message: "이 게시글을 신고하시겠습니까?",
            positiveBtnTitle: "신고",
            positiveBtnAction: {
                Task {
                    await vm.reportPost()
                }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    // MARK: - Comment

    /// 전송 가능한 댓글 텍스트를 계산합니다.
    ///
    /// 공백만 입력된 경우 전송을 막기 위해 앞뒤 공백과 줄바꿈을 제거한 값을 사용합니다.
    private var normalizedCommentText: String {
        vm.commentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 댓글 전송 버튼 활성화 여부를 판단합니다.
    ///
    /// 입력값이 비어 있지 않고, 현재 전송 중이 아닐 때만 활성화됩니다.
    private var canSendComment: Bool {
        !normalizedCommentText.isEmpty && !vm.isPostingComment
    }

    /// 댓글 목록 섹션을 렌더링합니다.
    ///
    /// - Parameter comments: 현재 게시글에 연결된 댓글 모델 배열입니다.
    private func commentSection(_ comments: [CommunityCommentModel]) -> some View {
        VStack(alignment: .leading, spacing: Constant.commentsSectionSpacing) {
            Text(String(format: Constant.commentsCountTitle, comments.count))
                .appFont(.subheadline, color: .grey600)

            ForEach(comments) { comment in
                commentItemView(comment)
            }
        }
    }

    /// 게시글 본문 카드와 번개 전용 보조 카드를 조합합니다.
    private var postSection: some View {
        Group {
            if let postItem = vm.postItem {
                VStack(spacing: Constant.postSectionSpacing) {
                    CommunityPostCard(
                        model: postItem,
                        onLikeTapped: {
                            await vm.toggleLike()
                        },
                        onScrapTapped: {
                            await vm.toggleScrap()
                        }
                    )

                    if postItem.category == .lighting {
                        CommunityLightningCard(model: postItem)
                    }
                }
            }
        }
    }

    /// 댓글 로딩 상태에 따라 댓글 섹션의 실제 UI를 선택합니다.
    @ViewBuilder
    private var commentStateSection: some View {
        switch vm.comments {
        case .idle, .loading:
            commentLoadingIndicator
        case .loaded(let comments):
            commentSection(comments)
        case .failed:
            commentFailedContent()
        }
    }

    /// 댓글 입력창의 펼침/접힘 상태에 맞는 하단 inset 콘텐츠를 제공합니다.
    @ViewBuilder
    private var commentInputInset: some View {
        if !isCommentInputHidden {
            commentInputSection
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            collapsedCommentInputButton
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
        }
    }

    /// 단일 댓글 셀을 구성합니다.
    ///
    /// 현재 사용자가 삭제 가능한 댓글인지 판단해 `CommunityCommentItem`에 전달합니다.
    private func commentItemView(_ comment: CommunityCommentModel) -> some View {
        let canDelete = vm.canDeleteComment(commentId: comment.commentId)
        return CommunityCommentItem(
            model: comment,
            canDelete: canDelete,
            onDeleteTapped: {
                await vm.deleteComment(commentId: comment.commentId)
            },
            onReportTapped: {
                await vm.reportComment(commentId: comment.commentId)
            }
        )
    }

    /// 스크롤 상태 변화에 따라 댓글 입력창 노출 상태를 조정합니다.
    ///
    /// 사용자가 스크롤을 멈추면 펼쳐진 입력창 상태를 유지하고,
    /// 스크롤 중에는 입력창을 접어 읽기 영역을 우선합니다.
    private func handleScrollPhaseChange(_ phase: ScrollPhase) {
        if phase == .idle {
            guard isCommentInputExpanded else { return }
            setCommentInputVisibility(hidden: false, expanded: true, focused: isCommentFieldFocused)
            return
        }
        hideCommentInputByScroll()
    }
    
    /// Failed - 데이터 로드 실패
    /// 게시글 상세 로드 실패
    private func postDetailFailedContent() -> some View {
        Group {
            switch vm.postDetailFailureReason {
            case .unavailable:
                ContentUnavailableView {
                    Label(
                        Constant.unavailableTitle,
                        systemImage: "text.page.slash"
                    )
                } description: {
                    Text(Constant.unavailableDescription)
                } actions: {
                    Button(Constant.unavailableActionTitle) {
                        dismiss()
                    }
                }
            case .generic:
                RetryContentUnavailableView(
                    title: Constant.failedTitle,
                    systemImage: Constant.failedSystemImage,
                    description: Constant.failedDescription,
                    retryTitle: Constant.retryTitle,
                    isRetrying: vm.postDetailState.isLoading,
                    minRetryButtonWidth: Constant.retryMinimumWidth,
                    minRetryButtonHeight: Constant.retryMinimumHeight
                ) {
                    await vm.fetchPostDetail()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// 댓글 로드 실패
    private func commentFailedContent() -> some View {
        RetryContentUnavailableView(
            title: Constant.commentLoadFailedTitle,
            systemImage: Constant.failedSystemImage,
            description: Constant.commentLoadFailedDescription,
            retryTitle: Constant.retryTitle,
            isRetrying: vm.comments.isLoading,
            minRetryButtonWidth: Constant.retryMinimumWidth,
            minRetryButtonHeight: Constant.retryMinimumHeight
        ) {
            await vm.fetchComments()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Comment Input

    /// 펼쳐진 댓글 입력창 전체 레이아웃입니다.
    private var commentInputSection: some View {
        VStack(spacing: Constant.commentSectionBottomSpacing) {
            commentTextEditor

            commentInputActionRow
                .padding(.horizontal, Constant.textFieldPadding.leading)
                .padding(.bottom, Constant.commentInputBottomPadding)
        }
        .background(.thinMaterial, in: .rect(cornerRadius: DefaultConstant.cornerRadius))
        .glassEffect(.regular, in: .rect(cornerRadius: DefaultConstant.cornerRadius))
        .padding(.horizontal, Constant.inputHorizontalPadding)
        .padding(.bottom, Constant.inputBottomOffset)
    }

    /// 댓글 입력창이 닫힌 상태에서 표시되는 축약 버튼입니다.
    private var collapsedCommentInputButton: some View {
        Button {
            setCommentInputVisibility(hidden: false, expanded: true, focused: true)
        } label: {
            Image(systemName: "plus.bubble")
                .font(.system(size: Constant.collapsedButtonFontSize, weight: .semibold))
                .foregroundStyle(.grey900)
                .frame(width: Constant.collapsedButtonSize, height: Constant.collapsedButtonSize)
                .background {
                    Circle().fill(.clear)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
        }
        .padding(.horizontal, Constant.inputHorizontalPadding)
        .padding(.bottom, Constant.inputBottomOffset)
    }

    /// 댓글 입력용 `TextField`와 placeholder를 조합한 입력 영역입니다.
    private var commentTextEditor: some View {
        ZStack(alignment: .topLeading) {
            TextField(
                "",
                text: $vm.commentText,
                axis: .vertical
            )
            .focused($isCommentFieldFocused)
            .appFont(.callout)
            .lineLimit(Constant.commentTextLineLimit)
            .frame(minHeight: Constant.textFieldMinHeight, alignment: .topLeading)
            .padding(.horizontal, Constant.commentTextFieldHorizontalPadding)
            .padding(.vertical, Constant.commentTextFieldVerticalPadding)

            if vm.commentText.isEmpty && !isCommentFieldFocused {
                Text(Constant.commentPrompt)
                    .appFont(.callout, color: Color(.placeholderText))
                    .padding(.horizontal, Constant.commentTextFieldHorizontalPadding)
                    .padding(.vertical, Constant.commentTextFieldVerticalPadding)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 댓글 로딩 중 상태를 나타내는 인디케이터입니다.
    private var commentLoadingIndicator: some View {
        Progress(message: Constant.commentLoadingMessage, size: .regular)
    }

    /// 댓글 전송 버튼이 포함된 입력창 하단 액션 행입니다.
    private var commentInputActionRow: some View {
        HStack(spacing: Constant.commentInputActionRowSpacing) {
            Spacer()

            Button {
                Task {
                    await sendComment()
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: Constant.sendButtonIconSize, weight: .semibold))
                    .foregroundStyle(canSendComment ? .white : .grey400)
            }
            .frame(width: Constant.sendButtonSize.width, height: Constant.sendButtonSize.height)
            .disabled(!canSendComment)
            .buttonBorderShape(.circle)
            .background(
                Circle()
                    .fill(canSendComment ? Constant.sendButtonActiveColor : Constant.sendButtonDisabledColor)
            )
        }
    }

    // MARK: - Private Function

    /// 현재 입력된 댓글을 전송하고 입력창을 닫습니다.
    ///
    /// 공백만 있는 입력은 무시하며, 실제 전송에는 정규화된 댓글 텍스트를 사용합니다.
    private func sendComment() async {
        let content = normalizedCommentText
        guard !content.isEmpty else { return }

        vm.commentText = ""
        await vm.postComment(content: content, parentId: 0)
        closeCommentInput()
    }

    /// 스크롤 중 댓글 입력창을 숨깁니다.
    private func hideCommentInputByScroll() {
        guard !isCommentInputHidden else { return }
        setCommentInputVisibility(hidden: true, expanded: false, focused: false)
    }

    /// 댓글 입력창을 닫고 포커스를 해제합니다.
    private func closeCommentInput() {
        setCommentInputVisibility(hidden: true, expanded: false, focused: false)
    }

    /// 댓글 입력창의 시각 상태와 포커스를 한 번에 갱신합니다.
    ///
    /// - Parameters:
    ///   - hidden: 입력창을 숨길지 여부입니다.
    ///   - expanded: 펼쳐진 입력창 상태를 유지할지 여부입니다.
    ///   - focused: 텍스트 필드 포커스를 적용할지 여부입니다.
    private func setCommentInputVisibility(hidden: Bool, expanded: Bool, focused: Bool) {
        withAnimation(Constant.commentInputAnimation) {
            isCommentInputHidden = hidden
            isCommentInputExpanded = expanded
        }
        isCommentFieldFocused = focused
    }
}
