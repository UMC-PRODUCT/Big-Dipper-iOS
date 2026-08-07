//
//  StaffNoticeView.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/22/26.
//

import SwiftUI
import UMCFoundation
import CoreDI
import CoreDesignSystem
import CoreUIComponents
import NoticeDomain

// MARK: - StaffNoticeView
/// 운영진 공지 전용 화면 (안 B: 별도 분리)
///
/// `NoticeView`와 독립된 화면으로, `canAccessStaffNotice` 사용자에게만
/// 툴바 아이콘을 통해 진입점이 노출됩니다.
public struct StaffNoticeView: View {

    // MARK: - Properties
    @AppStorage(AppStorageKey.memberRole) private var memberRoleRaw: String = ""
    @AppStorage(AppStorageKey.schoolId) private var schoolId: String = ""
    @AppStorage(AppStorageKey.gisuId) private var gisuId: String = ""
    @State private var viewModel: StaffNoticeViewModel
    @State private var search: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isRetryingNotices: Bool = false
    private let onNoticeSelected: (NoticeDetail) -> Void
    private let onCreateNotice: (String?, EditorMainCategory) -> Void

    // MARK: - Initializer
    public init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        onNoticeSelected: @escaping (NoticeDetail) -> Void,
        onCreateNotice: @escaping (String?, EditorMainCategory) -> Void
    ) {
        self.onNoticeSelected = onNoticeSelected
        self.onCreateNotice = onCreateNotice
        _viewModel = State(
            initialValue: StaffNoticeViewModel(container: container, errorHandler: errorHandler)
        )
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let searchPlaceholder: String = "제목, 내용 검색"
        static let loadingMessage: String = "공지를 불러오고 있어요"
        static let emptyTitle: String = "아직 등록된 공지사항이 없어요"
        static let emptySystemImage: String = "exclamationmark.triangle.text.page"
        static let emptyDescription: String = "운영진 공지사항이 등록되면 이곳에 표시됩니다"
        static let failedTitle: String = "불러오지 못했어요"
        static let failedSystemImage: String = "exclamationmark.triangle"
        static let failedDescription: String = "공지사항을 불러오지 못했습니다. 잠시 후 다시 시도해주세요."
        static let retryTitle: String = "다시 시도"
        static let retryMinimumWidth: CGFloat = 72
        static let retryMinimumHeight: CGFloat = 20
        static let loadingMoreBottomPadding: CGFloat = DefaultSpacing.spacing16
        static let chipSpacing: CGFloat = DefaultSpacing.spacing8
        static let defaultNavigationTitle: String = "운영진 공지"
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if viewModel.accessibleTabs.isEmpty {
                noAccessContent
            } else {
                mainContent
            }
        }
        .navigationTitle(viewModel.selectedTab?.labelText ?? Constants.defaultNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { staffToolbarContent }
        .task {
            applyUserContext()
            await viewModel.fetchNotices()
        }
        .onChange(of: staffContextSignature) { _, _ in
            applyUserContext()
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .umcDefaultBackground()
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            staffTabChips
            content
        }
        .searchable(text: $search, prompt: Constants.searchPlaceholder)
        .searchToolbarBehavior(.minimize)
        .onChange(of: search) { _, newValue in
            handleSearchChanged(newValue)
        }
    }

    // MARK: - Staff Tab Chips

    private var staffTabChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.chipSpacing) {
                ForEach(viewModel.accessibleTabs) { tab in
                    ChipButton(
                        tab.labelText,
                        isSelected: viewModel.selectedTab == tab
                    ) {
                        viewModel.selectTab(tab)
                    }
                    .buttonSize(.medium)
                    .accessibilityLabel("\(tab.labelText) 탭")
                    .accessibilityAddTraits(viewModel.selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.vertical, DefaultSpacing.spacing8)
        }
    }

    // MARK: - Content Rendering

    @ViewBuilder
    private var content: some View {
        if viewModel.hasNoAccessFromServer {
            noAccessContent
        } else {
            switch viewModel.noticeItems {
            case .idle, .loading:
                progressContent
            case .loaded(let items):
                noticeContent(items)
            case .failed:
                failedContent()
            }
        }
    }

    @ViewBuilder
    private func noticeContent(_ data: [NoticeItemModel]) -> some View {
        if data.isEmpty {
            unavailableContent
        } else {
            availableContent(data)
        }
    }

    private var progressContent: some View {
        VStack {
            Spacer()
            Progress(message: Constants.loadingMessage)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func availableContent(_ data: [NoticeItemModel]) -> some View {
        List(data) { item in
            noticeRow(item)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(DefaultConstant.defaultListPadding)
        }
        .overlay(alignment: .bottom) {
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.bottom, Constants.loadingMoreBottomPadding)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .tint(.indigo500)
        .refreshable {
            await reloadWithMinimumDuration()
        }
    }

    private func failedContent() -> some View {
        RetryContentUnavailableView(
            title: Constants.failedTitle,
            systemImage: Constants.failedSystemImage,
            description: Constants.failedDescription,
            retryTitle: Constants.retryTitle,
            isRetrying: isRetryingNotices,
            minRetryButtonWidth: Constants.retryMinimumWidth,
            minRetryButtonHeight: Constants.retryMinimumHeight
        ) {
            await retryNotices()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var unavailableContent: some View {
        ContentUnavailableView(
            Constants.emptyTitle,
            systemImage: Constants.emptySystemImage,
            description: Text(Constants.emptyDescription)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var noAccessContent: some View {
        NoAccessContentView()
    }

    // MARK: - Row

    private func noticeRow(_ item: NoticeItemModel) -> some View {
        NoticeItem(model: item) {
            onNoticeSelected(item.toNoticeDetail())
        }
        .task(id: item.id) {
            await viewModel.loadNextPageIfNeeded(currentItem: item)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var staffToolbarContent: some ToolbarContent {
        if let category = writableCategoryForSelectedTab {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onCreateNotice(gisuId, category)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .imageScale(.medium)
                }
                .accessibilityLabel("운영진 공지 작성")
            }
        }
    }

    private var writableCategoryForSelectedTab: EditorMainCategory? {
        guard let tab = viewModel.selectedTab,
              let role = viewModel.memberRole else { return nil }

        switch tab {
        case .centralMember where role.canWriteCentralAllNotice:
            return .management(.centralAll)
        case .schoolCore where role.canWriteSchoolCoreNotice:
            return .management(.schoolCore)
        case .schoolPartLeader where role.canWriteSchoolPartLeaderNotice:
            return .management(.schoolPartLeader)
        default:
            return nil
        }
    }

    // MARK: - User Context

    private func applyUserContext() {
        viewModel.applyUserContext(
            memberRoleRawValue: memberRoleRaw,
            schoolId: schoolId,
            gisuId: gisuId
        )
    }

    private var staffContextSignature: String {
        "\(memberRoleRaw)|\(schoolId)|\(gisuId)"
    }

    // MARK: - Retry / Reload

    @MainActor
    private func retryNotices() async {
        guard !isRetryingNotices else { return }
        isRetryingNotices = true
        defer { isRetryingNotices = false }
        await viewModel.retryCurrentRequest()
    }

    @MainActor
    private func reloadWithMinimumDuration() async {
        async let reloadTask: Void = reloadCurrentList()
        async let delayTask: Void = { try? await Task.sleep(for: .seconds(2)) }()
        _ = await (reloadTask, delayTask)
    }

    @MainActor
    private func reloadCurrentList() async {
        if viewModel.isSearchMode,
           !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await viewModel.searchNotices(keyword: viewModel.searchQuery)
        } else {
            await viewModel.fetchNotices()
        }
    }

    // MARK: - Search

    private func handleSearchChanged(_ newValue: String) {
        searchTask?.cancel()
        let keyword = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            if keyword.isEmpty {
                await viewModel.clearSearch()
            } else {
                await viewModel.searchNotices(keyword: keyword)
            }
        }
    }
}
