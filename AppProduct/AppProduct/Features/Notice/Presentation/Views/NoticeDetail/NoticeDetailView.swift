//
//  NoticeDetailView.swift
//  AppProduct
//
//  Created by 이예지 on 2/1/26.
//

import SwiftUI

/// 공지사항 상세 화면
///
/// 공지 본문, 투표, 이미지, 링크를 표시하며 열람 통계 및 수정/삭제 기능을 제공합니다.
struct NoticeDetailView: View {

    // MARK: - Property

    @Environment(\.di) var di
    @State private var viewModel: NoticeDetailViewModel
    @State private var isReadStatusBarCollapsed: Bool = false
    @State private var isRetryingNoticeDetail: Bool = false
    private let errorHandler: ErrorHandler

    // MARK: - Initializer
    init(container: DIContainer, errorHandler: ErrorHandler, model: NoticeDetail) {
        self.errorHandler = errorHandler
        self._viewModel = .init(wrappedValue: .init(container: container, errorHandler: errorHandler, model: model))
    }

    // MARK: - Constants
    fileprivate enum Constants {
        static let profileSize: CGSize = .init(width: 20, height: 20)
        static let horizontalPadding: CGFloat = DefaultConstant.defaultSafeHorizon
        static let topSectionSpacing: CGFloat = DefaultSpacing.spacing16
        static let subInfoSpacing: CGFloat = DefaultSpacing.spacing8
        static let tagSpacing: CGFloat = DefaultSpacing.spacing8
        static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
        static let contentToImageSpacing: CGFloat = 20
        static let contentToLinkSpacing: CGFloat = 20
        static let imageToLinkSpacing: CGFloat = 10
        static let attachmentToVoteSpacing: CGFloat = 20
        static let contentToVoteSpacing: CGFloat = 20
        static let linkItemSpacing: CGFloat = DefaultSpacing.spacing12
        static let bottomButtonPadding: CGFloat = DefaultSpacing.spacing16
        static let detailSheetDetents: Set<PresentationDetent> = [.fraction(0.72)]
        static let defaultProfileImageName: String = "defaultProfile"
        static let noticeEditTitle: String = "수정하기"
        static let noticeDeleteTitle: String = "삭제하기"
        static let editIcon: String = "pencil"
        static let deleteIcon: String = "trash"
        static let collapsedButtonSize: CGFloat = 60
        static let collapsedButtonIcon: String = "chart.bar.xaxis"
        static let collapsedButtonIconSize: CGFloat = 22
        static let collapsedVerticalOffset: CGFloat = 22
        static let collapsedTrailingPadding: CGFloat = 22
        static let collapseAnimation: Animation = .spring(response: 0.36, dampingFraction: 0.88)
        static let failedTitleText: String = "공지사항을 불러오지 못했습니다."
        static let failedIconName: String = "exclamationmark.triangle"
    }

    // MARK: - Body

    var body: some View {
        content
            .navigation(naviTitle: .noticeDetail, displayMode: .inline)
            .navigationSubtitle(noticeTypeSubtitle)
            .toolbar { toolbarContent }
            .safeAreaBar(edge: .bottom, alignment: .center, content: expandedReadStatusInset)
            .safeAreaBar(edge: .bottom, alignment: .trailing, content: collapsedReadStatusInset)
            .sheet(isPresented: $viewModel.showReadStatusSheet, content: readStatusSheet)
            .alertPrompt(item: $viewModel.alertPrompt)
            .task { await onTask() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.noticeState {
        case .idle, .loading:
            Progress()
        case .loaded(let noticeDetail):
            detailContent(noticeDetail)
        case .failed(let error):
            failedSection(error: error)
        }
    }

    /// 공지 상세 로드 실패 상태 UI
    private func failedSection(error: AppError) -> some View {
        RetryContentUnavailableView(
            title: Constants.failedTitleText,
            systemImage: Constants.failedIconName,
            description: error.userMessage,
            isRetrying: isRetryingNoticeDetail
        ) {
            await retryNoticeDetail()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @MainActor
    private func retryNoticeDetail() async {
        guard !isRetryingNoticeDetail else { return }
        isRetryingNoticeDetail = true
        defer { isRetryingNoticeDetail = false }
        await viewModel.fetchNoticeDetail()
    }

    /// 공지 상세 데이터가 로드된 상태의 스크롤 본문
    private func detailContent(_ data: NoticeDetail) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Constants.topSectionSpacing) {
                topSection(data)
                Divider()
                    .padding(.horizontal, Constants.horizontalPadding)
                bottomSection(data)
                Spacer()
            }
        }
        .onScrollPhaseChange { _, newPhase in
            if newPhase != .idle {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isReadStatusBarCollapsed = true
                }
            }
        }
    }

    // MARK: - Top Section

    /// 공지 제목, 작성자, 작성일, 수신 대상을 표시합니다.
    private func topSection(_ data: NoticeDetail) -> some View {
        VStack(alignment: .leading, spacing: Constants.topSectionSpacing) {
            mainInfo(data)
            subInfo(data)
        }
        .padding(.horizontal, Constants.horizontalPadding)
    }

    /// 필독 칩 + 공지 제목 영역
    private func mainInfo(_ data: NoticeDetail) -> some View {
        VStack(alignment: .leading, spacing: Constants.topSectionSpacing) {
            Text(data.title)
                .appFont(.title2Emphasis)
        }
    }

    /// 작성자 프로필, 작성일, 수신 대상 영역
    private func subInfo(_ data: NoticeDetail) -> some View {
        VStack(alignment: .leading, spacing: Constants.subInfoSpacing) {
            HStack {
                HStack {
                    authorProfileImage(data)
                    Text(viewModel.displayedAuthorProfileLine(for: data))
                        .lineLimit(1)
                }
                Spacer()
                Text(data.createdAt.toYearMonthDay())
            }
            .appFont(.subheadline, color: .grey700)

            FlowLayout(spacing: Constants.tagSpacing) {
                ForEach(Array(data.tags.enumerated()), id: \.offset) { _, tag in
                    detailTag(tag)
                }
            }
        }
    }

    @ViewBuilder
    private func authorProfileImage(_ data: NoticeDetail) -> some View {
        if let imageURL = viewModel.displayedAuthorImageURL(for: data),
           !imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            RemoteImage(
                urlString: imageURL,
                size: Constants.profileSize,
                cornerRadius: Constants.profileSize.width / 2,
                placeholderImage: Constants.defaultProfileImageName
            )
        } else if !viewModel.hasResolvedAuthorProfile || viewModel.isAuthorProfileLoading {
            Circle()
                .fill(.grey100)
                .frame(width: Constants.profileSize.width, height: Constants.profileSize.height)
                .overlay {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.grey500)
                }
        } else {
            Image(.defaultProfile)
                .resizable()
                .frame(width: Constants.profileSize.width, height: Constants.profileSize.height)
                .clipShape(.circle)
        }
    }

    private func detailTag(_ tag: NoticeItemTag) -> some View {
        Text(tag.text)
            .foregroundStyle(.grey000)
            .appFont(.caption1Emphasis, weight: .regular)
            .padding(Constants.tagPadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .fill(tag.backColor)
            }
            .glassEffect(.clear, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
    }

    // MARK: - Bottom Section

    /// 공지 본문/투표/이미지/링크를 순서대로 구성합니다.
    private func bottomSection(_ data: NoticeDetail) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            MarkdownRenderedView(markdown: data.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Constants.horizontalPadding)

            if !data.images.isEmpty {
                NoticeImageCard(imageURLs: data.images)
                    .padding(.top, Constants.contentToImageSpacing)
            }

            if let vote = data.vote {
                NoticeVoteCard(
                    vote: vote,
                    isSubmitting: viewModel.isSubmittingVote,
                    container: di,
                    onVote: { optionIds in
                        Task {
                            await viewModel.handleVote(voteId: vote.id, optionIds: optionIds)
                        }
                    },
                    onUpdateVote: { optionIds in
                        Task {
                            await viewModel.handleUpdateVote(
                                voteId: vote.id,
                                optionIds: optionIds
                            )
                        }
                    }
                )
                .padding(
                    .top,
                    (data.images.isEmpty && data.links.isEmpty)
                    ? Constants.contentToVoteSpacing
                    : Constants.attachmentToVoteSpacing
                )
                .padding(.horizontal, Constants.horizontalPadding)
            } else if viewModel.isVoteLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .padding(
                        .top,
                        data.images.isEmpty
                        ? Constants.contentToVoteSpacing
                        : Constants.attachmentToVoteSpacing
                    )
                    .padding(.horizontal, Constants.horizontalPadding)
            }

            if !data.links.isEmpty {
                VStack(spacing: Constants.linkItemSpacing) {
                    ForEach(Array(data.links.enumerated()), id: \.offset) { _, link in
                        NoticeLinkCard(url: link)
                            .padding(.horizontal, Constants.horizontalPadding)
                    }
                }
                .padding(.top, (data.images.isEmpty && data.vote == nil) ? Constants.contentToLinkSpacing : Constants.imageToLinkSpacing)
            }
        }
    }

    // MARK: - Toolbar

    /// 수정/삭제 메뉴를 포함하는 네비게이션 툴바
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if currentNotice != nil, !toolbarActions.isEmpty {
            ToolBarCollection.ToolbarTrailingMenu(actions: toolbarActions)
        }
    }

    /// 권한에 따라 동적으로 구성되는 툴바 액션 목록
    private var toolbarActions: [ToolBarCollection.ToolbarTrailingMenu.ActionItem] {
        var actions: [ToolBarCollection.ToolbarTrailingMenu.ActionItem] = []

        if viewModel.canEditNotice {
            actions.append(
                .init(
                    title: Constants.noticeEditTitle,
                    icon: Constants.editIcon,
                    action: handleEditNotice
                )
            )
        }

        if viewModel.canDeleteNotice {
            actions.append(
                .init(
                    title: Constants.noticeDeleteTitle,
                    icon: Constants.deleteIcon,
                    role: .destructive,
                    action: handleDeleteNotice
                )
            )
        }

        return actions
    }

    // MARK: - Bottom Bar

    /// 펼침 상태 수신 확인 카드 inset
    @ViewBuilder
    private func expandedReadStatusInset() -> some View {
        if shouldShowReadStatusInset && !isReadStatusBarCollapsed {
            NoticeReadStatusButton(
                confirmedCount: viewModel.confirmedCount,
                totalCount: viewModel.totalCount,
                readRate: viewModel.readRate,
                isLoading: viewModel.readStatics == nil
            ) {
                viewModel.openReadStatusSheet()
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.bottom, Constants.bottomButtonPadding)
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
            .animation(Constants.collapseAnimation, value: isReadStatusBarCollapsed)
        }
    }

    /// 압축 상태 원형 버튼 inset
    @ViewBuilder
    private func collapsedReadStatusInset() -> some View {
        if shouldShowReadStatusInset && isReadStatusBarCollapsed {
            Button(action: expandReadStatusBar) {
                Image(systemName: Constants.collapsedButtonIcon)
                    .font(.system(size: Constants.collapsedButtonIconSize, weight: .semibold))
                    .foregroundStyle(.grey900)
                    .frame(
                        width: Constants.collapsedButtonSize,
                        height: Constants.collapsedButtonSize
                    )
                    .background {
                        Circle()
                            .fill(.clear)
                            .glassEffect(
                                .regular.interactive(),
                                in: .circle
                            )
                    }
            }
            .padding(.trailing, Constants.collapsedTrailingPadding)
            .padding(.bottom, Constants.bottomButtonPadding)
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
            .animation(Constants.collapseAnimation, value: isReadStatusBarCollapsed)
        }
    }

    /// 축소된 하단 바를 다시 펼칩니다.
    private func expandReadStatusBar() {
        withAnimation(Constants.collapseAnimation) {
            isReadStatusBarCollapsed = false
        }
    }

    /// 수신 확인 현황 시트를 구성합니다.
    private func readStatusSheet() -> some View {
        NoticeReadStatusSheet(viewModel: viewModel)
            .presentationDetents(Constants.detailSheetDetents)
            .interactiveDismissDisabled()
    }

    // MARK: - Task

    /// 화면 진입 시 읽음 처리, 열람 현황, 권한, 상세 데이터를 로드합니다.
    @MainActor
    private func onTask() async {
        viewModel.updateErrorHandler(errorHandler)

        guard viewModel.noticeID > 0 else {
            viewModel.noticeState = .failed(.unknown(message: "유효하지 않은 공지입니다."))
            return
        }

        async let detailTask: Void = viewModel.fetchNoticeDetail()
        async let permissionTask: Void = viewModel.fetchNoticePermission()
        async let markAsReadTask = viewModel.markAsReadIfNeeded()
        
        await detailTask
        await permissionTask
        _ = await markAsReadTask
        // statics는 markAsRead 완료 후 순차 조회하여 서버 반영값을 정확히 수신
        await viewModel.prefetchReadStaticsIfNeeded()
    }

    // MARK: - Private Methods

    /// 공지 수정 처리
    private func handleEditNotice() {
        guard viewModel.isDetailPreparedForEdit else {
            viewModel.alertPrompt = AlertPrompt(
                id: .init(),
                title: "잠시 후 다시 시도해주세요",
                message: "공지 상세 정보를 불러오는 중입니다.",
                positiveBtnTitle: "확인"
            )
            return
        }
        guard viewModel.canEditNotice else {
            showNoPermissionAlert()
            return
        }

        Task {
            await openEditorUsingCurrentOrHydratedDetail()
        }
    }

    /// 현재 상세 모델을 우선 사용하고, 이미지 메타데이터가 비어있을 때만 1회 보강 조회 후 수정 화면으로 진입합니다.
    @MainActor
    private func openEditorUsingCurrentOrHydratedDetail() async {
        guard var notice = currentNotice else { return }

        // 디버그/요약 모델 경로에서 이미지 메타데이터(id)가 비어있으면
        // 에디터에서 기존 이미지를 복원할 수 없으므로 보강 조회를 수행합니다.
        let needsImageHydration = !notice.images.isEmpty &&
            (notice.imageItems.isEmpty || notice.imageItems.contains(where: { $0.id.isEmpty }))

        if needsImageHydration {
            do {
                let hydrated = try await viewModel.noticeUseCase.getDetailNotice(noticeId: viewModel.noticeID)
                notice = hydrated
                viewModel.noticeState = .loaded(hydrated)
            } catch {
                // 보강 조회 실패 시 현재 모델로 계속 진행
            }
        }

        let noticeID = Int(notice.id) ?? 0
        guard noticeID > 0 else { return }

        let editMode = NoticeEditorMode.edit(noticeId: noticeID, notice: notice)
        pathStore.noticePath.append(.notice(.editor(mode: editMode, selectedGisuId: nil)))
    }

    /// 공지 삭제 처리
    private func handleDeleteNotice() {
        guard currentNotice != nil else { return }
        guard viewModel.canDeleteNotice else {
            showNoPermissionAlert()
            return
        }

        viewModel.showDeleteConfirmation(onDeleteRequested: closeDetailScreenImmediately)
    }

    /// 삭제 확인 시 상세 화면을 즉시 닫습니다.
    private func closeDetailScreenImmediately() {
        guard !pathStore.noticePath.isEmpty else { return }
        pathStore.noticePath.removeLast()
    }

    /// 수정/삭제 권한 없음 안내
    private func showNoPermissionAlert() {
        viewModel.alertPrompt = AlertPrompt(
            id: .init(),
            title: "권한 없음",
            message: "해당 공지에 대한 권한이 없습니다.",
            positiveBtnTitle: "확인"
        )
    }

    /// PathStore 접근
    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    /// 공지 상세의 타입(중앙/지부/교내/파트)을 내비게이션 서브타이틀로 노출합니다.
    private var noticeTypeSubtitle: String {
        currentNotice?.noticeType.rawValue ?? ""
    }

    /// 현재 로드된 공지 상세 데이터 (loaded 상태일 때만 존재)
    private var currentNotice: NoticeDetail? {
        viewModel.noticeState.value
    }

    /// 상세 로드 실패/로딩 상태에서는 하단 수신 확인 inset을 숨깁니다.
    private var shouldShowReadStatusInset: Bool {
        guard viewModel.canViewReadStatus else { return false }
        if case .loaded = viewModel.noticeState {
            return true
        }
        return false
    }
}
