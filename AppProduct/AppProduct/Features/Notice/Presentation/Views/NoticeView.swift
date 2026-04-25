//
//  NoticeView.swift
//  AppProduct
//
//  Created by 이예지 on 1/14/26.
//

import SwiftUI

// MARK: - NoticeView
/// 공지사항 메인 화면
struct NoticeView: View {
    
    // MARK: - Properties
    @Environment(\.di) var di
    @Environment(ErrorHandler.self) var errorHandler
    @AppStorage(AppStorageKey.schoolName) private var schoolName: String = ""
    @AppStorage(AppStorageKey.chapterName) private var chapterName: String = ""
    @AppStorage(AppStorageKey.responsiblePart) private var responsiblePart: String = ""
    @AppStorage(AppStorageKey.organizationType) private var organizationType: String = ""
    @AppStorage(AppStorageKey.memberRole) private var memberRoleRaw: String = ""
    @AppStorage(AppStorageKey.chapterId) private var chapterId: Int = 0
    @AppStorage(AppStorageKey.schoolId) private var schoolId: Int = 0
    @AppStorage(AppStorageKey.generationOrganizations) private var generationOrganizationsJSON: String = "[]"
    @AppStorage(AppStorageKey.noticeSelectedGisuId) private var noticeSelectedGisuId: Int = 0
    @State private var viewModel: NoticeViewModel
    @State private var search: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isRetryingNotices: Bool = false
    
    /// PathStore 접근
    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }
    
    // MARK: - Initializer
    init(container: DIContainer, errorHandler: ErrorHandler) {
        _viewModel = State(
            initialValue: NoticeViewModel(container: container, errorHandler: errorHandler)
        )
    }
    
    // MARK: - Constants
    /// 화면 내 반복되는 문구/수치를 한 곳에서 관리합니다.
    private enum Constants {
        /// 검색창 placeholder
        static let searchPlaceholder: String = "제목, 내용 검색"
        /// 초기/재로딩 상태 안내 문구
        static let loadingMessage: String = "공지를 불러오고 있어요"
        /// 빈 공지 상태 문구
        static let emptyTitle: String = "아직 등록된 공지사항이 없어요"
        static let emptySystemImage: String = "exclamationmark.triangle.text.page"
        static let emptyDescription: String = "운영진이 공지사항을 등록하면 이곳에 표시됩니다"
        /// 실패 상태 문구
        static let failedTitle: String = "불러오지 못했어요"
        static let failedSystemImage: String = "exclamationmark.triangle"
        static let failedDescription: String = "공지사항을 불러오지 못했습니다. 잠시 후 다시 시도해주세요."
        /// 재시도 버튼 문구/크기
        static let retryTitle: String = "다시 시도"
        static let retryMinimumWidth: CGFloat = 72
        static let retryMinimumHeight: CGFloat = 20
        /// 무한 스크롤 추가 로딩 인디케이터 하단 여백
        static let loadingMoreBottomPadding: CGFloat = DefaultSpacing.spacing16
        /// 사용자 컨텍스트 변경 감지용 signature 구분자
        static let userContextSeparator: String = "|"
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: noticePathBinding) {
            content
            .searchable(text: $search, prompt: Constants.searchPlaceholder)
            .searchToolbarBehavior(.minimize)
            .navigationTitle(viewModel.selectedMainFilter.labelText)
            .onChange(of: search) { _, newValue in
                handleSearchChanged(newValue)
            }
            .toolbar { toolbarContent }
            .safeAreaBar(edge: .top) { topSafeAreaContent }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: NavigationDestination.self, destination: navigationDestinationView)
            .task {
                applyUserContext()
                syncSelectedGisuIdForNoticeEditor()
                viewModel.fetchGisuList()
            }
            .onChange(of: pathStore.noticePath.count) { oldCount, newCount in
                guard newCount < oldCount, newCount == 0 else { return }

                Task {
                    await reloadNoticesAfterReturningFromDetail()
                }
            }
            .onChange(of: viewModel.selectedGeneration) { _, _ in
                syncSelectedGisuIdForNoticeEditor()
            }
            .onChange(of: userContextSignature) { _, _ in
                applyUserContext()
            }
            .onReceive(NotificationCenter.default.publisher(for: .generationMappingsUpdated)) { _ in
                viewModel.fetchGisuList()
            }
            .onDisappear {
                searchTask?.cancel()
            }
            .umcDefaultBackground()
        }
    }

    // MARK: - Content Rendering
    /// Loadable 상태에 따라 본문을 분기 렌더링합니다.
    @ViewBuilder
    private var content: some View {
        switch viewModel.noticeItems {
        case .idle, .loading:
            progressContent
        case .loaded(let noticeItem):
            noticeContent(noticeItem)
        case .failed:
            failedContent()
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
    
    /// idle, loading
    private var progressContent: some View {
        VStack {
            Spacer()
            Progress(message: Constants.loadingMessage)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    /// Loaded - 데이터가 있을 때
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
            await reloadCurrentNoticeListWithMinimumDuration()
        }
    }
    
    
    /// Failed - 데이터 로드 실패
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
    
    /// Loaded - 데이터가 없을 때
    private var unavailableContent: some View {
        ContentUnavailableView(
            Constants.emptyTitle,
            systemImage: Constants.emptySystemImage,
            description: Text(Constants.emptyDescription)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Retry
    @MainActor
    private func retryNotices() async {
        guard !isRetryingNotices else { return }
        isRetryingNotices = true
        defer { isRetryingNotices = false }
        await viewModel.retryCurrentRequest()
    }

    @MainActor
    private func reloadNoticesAfterReturningFromDetail() async {
        if viewModel.isSearchMode,
           !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await viewModel.searchNotices(keyword: viewModel.searchQuery)
        } else {
            await viewModel.fetchNotices()
        }
    }

    @MainActor
    private func reloadCurrentNoticeList() async {
        await reloadNoticesAfterReturningFromDetail()
    }

    @MainActor
    private func reloadCurrentNoticeListWithMinimumDuration() async {
        async let reloadTask: Void = reloadCurrentNoticeList()
        async let delayTask: Void = waitForMinimumRefreshDuration()
        _ = await (reloadTask, delayTask)
    }

    private func waitForMinimumRefreshDuration() async {
        try? await Task.sleep(for: .seconds(2))
    }

    // MARK: - Search
    /// 검색어 변경 시 1초 디바운스 후 실시간 검색합니다.
    private func handleSearchChanged(_ newValue: String) {
        searchTask?.cancel()
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - Row
    /// 공지 셀 탭/무한스크롤 트리거를 묶은 row 구성입니다.
    private func noticeRow(_ item: NoticeItemModel) -> some View {
        NoticeItem(model: item) {
            let noticeDetail = item.toNoticeDetail()
            pathStore.noticePath.append(.notice(.detail(detailItem: noticeDetail)))
        }
        .task(id: item.id) {
            await viewModel.loadNextPageIfNeeded(currentItem: item)
        }
    }

    // MARK: - User Context
    /// AppStorage 사용자 컨텍스트를 ViewModel 필터 라벨에 반영합니다.
    private func applyUserContext() {
        viewModel.applyUserContext(
            schoolName: schoolName,
            chapterName: chapterName,
            responsiblePart: responsiblePart,
            organizationTypeRawValue: organizationType,
            chapterId: chapterId,
            schoolId: schoolId,
            memberRoleRawValue: memberRoleRaw,
            generationOrganizationsJSON: generationOrganizationsJSON
        )
    }

    /// 공지 생성 진입에 사용할 현재 선택 기수 ID를 AppStorage에 동기화합니다.
    private func syncSelectedGisuIdForNoticeEditor() {
        noticeSelectedGisuId = viewModel.selectedGisuIdForEditor ?? 0
    }

    /// 사용자 컨텍스트 변경 감지를 위한 서명 문자열입니다.
    private var userContextSignature: String {
        [
            schoolName,
            chapterName,
            responsiblePart,
            organizationType,
            memberRoleRaw,
            String(chapterId),
            String(schoolId),
            generationOrganizationsJSON
        ]
            .joined(separator: Constants.userContextSeparator)
    }
    
    // MARK: - Bindings
    /// 기수 선택 바인딩
    private var generationBinding: Binding<Generation> {
        Binding(
            get: { viewModel.selectedGeneration },
            set: { viewModel.selectGeneration($0) }
        )
    }

    /// 현재 탭의 Notice NavigationPath 바인딩입니다.
    private var noticePathBinding: Binding<[NavigationDestination]> {
        Binding(
            get: { pathStore.noticePath },
            set: { newValue in
                // NavigationStack이 동일 경로를 다시 쓰는 경우를 무시해
                // "tried to update multiple times per frame" 경고를 줄입니다.
                guard pathStore.noticePath != newValue else { return }
                pathStore.noticePath = newValue
            }
        )
    }

    // MARK: - Toolbar / Navigation Builders
    /// 상단 툴바(기수 + 메인 필터)를 구성합니다.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !viewModel.baseMainFilterItems.isEmpty {
            ToolbarTitleMenu {
                ForEach(viewModel.baseMainFilterItems) { item in
                    Button {
                        viewModel.selectMainFilter(item)
                        #if DEBUG
                        print("[Notice][MainFilter] tapped: \(item.labelText)")
                        #endif
                    } label: {
                        Label(item.labelText, systemImage: item.labelIcon)
                            .imageScale(.small)
                            .font(.subheadline)
                    }
                }

                if viewModel.canSelectPartFilter {
                    Menu {
                        ForEach(viewModel.partFilterItems) { part in
                            Button {
                                viewModel.selectMainFilter(.part(part))
                                #if DEBUG
                                print("[Notice][MainFilter] part tapped: \(part.displayName)")
                                #endif
                            } label: {
                                Label(part.displayName, systemImage: part.iconName)
                                    .font(.subheadline)
                            }
                        }
                    } label: {
                        Label("파트", systemImage: "person.3.fill")
                            .imageScale(.small)
                            .font(.subheadline)
                    }
                }
            }
        }

        ToolBarCollection.GenerationFilter(
            title: viewModel.selectedGeneration.title,
            generations: viewModel.generations,
            selection: generationBinding
        )
    }
    /// 메인 필터 타입에 따라 노출되는 서브필터 영역입니다.
    @ViewBuilder
    private var topSafeAreaContent: some View {
        if viewModel.showSubFilter {
            NoticeSubFilter(viewModel: viewModel)
        }
    }

    /// Notice 탭 내 destination 라우팅 뷰입니다.
    private func navigationDestinationView(_ destination: NavigationDestination) -> some View {
        NavigationRoutingView(destination: destination)
    }
}
