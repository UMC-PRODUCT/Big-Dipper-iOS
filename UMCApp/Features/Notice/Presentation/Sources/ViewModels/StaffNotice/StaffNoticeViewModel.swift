//
//  StaffNoticeViewModel.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/22/26.
//

import Foundation
import SwiftUI
import UMCFoundation
import CoreDI
import NoticeDomain

// MARK: - StaffNoticeViewModel
/// 운영진 공지 전용 ViewModel
///
/// `NoticeViewModel`과 책임을 분리하여 챌린저/운영진 상태를 격리합니다.
/// 역할 기반 탭 가시성, 탭별 `noticeTab` + `schoolId` 매핑, 페이지네이션을 담당합니다.
@Observable
final class StaffNoticeViewModel {

    // MARK: - Property

    private let container: DIContainer

    private var noticeUseCase: NoticeUseCaseProtocol {
        container.resolve(NoticeUseCaseProtocol.self)
    }

    private var noticeReadRepository: NoticeReadRepositoryProtocol {
        container.resolve(NoticeReadRepositoryProtocol.self)
    }

    private(set) var memberRole: ManagementTeam?
    private(set) var schoolId: String = ""
    private(set) var gisuId: String = ""

    private(set) var accessibleTabs: [StaffNoticeTab] = []
    var selectedTab: StaffNoticeTab?

    var noticeItems: Loadable<[NoticeItemModel]> = .idle
    var pagingState = NoticePagingState()
    var hasNoAccessFromServer: Bool = false

    var isSearchMode: Bool = false
    var searchQuery: String = ""

    let errorHandler: ErrorHandler

    private var isFetchingFirstPage: Bool = false
    private var tabSwitchTask: Task<Void, Never>?

    private enum Pagination {
        static let pageSize: Int = 20
        static let sort: [String] = ["createdAt,DESC"]
    }

    var isLoadingMore: Bool {
        pagingState.isLoadingMore
    }

    // MARK: - Lifecycle

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
    }

    // MARK: - Context

    func applyUserContext(
        memberRoleRawValue: String,
        schoolId: String,
        gisuId: String
    ) {
        self.memberRole = ManagementTeam(rawValue: memberRoleRawValue)
        self.schoolId = schoolId
        self.gisuId = gisuId
        self.accessibleTabs = StaffNoticeTab.accessibleTabs(for: memberRole)

        if let selectedTab, !accessibleTabs.contains(selectedTab) {
            self.selectedTab = accessibleTabs.first
        } else if selectedTab == nil {
            self.selectedTab = accessibleTabs.first
        }
    }

    // MARK: - Tab Selection

    func selectTab(_ tab: StaffNoticeTab) {
        guard accessibleTabs.contains(tab), tab != selectedTab else { return }
        selectedTab = tab
        isSearchMode = false
        searchQuery = ""
        if hasNoAccessFromServer {
            hasNoAccessFromServer = false
            noticeItems = .loading
        }

        // 이전 탭 요청이 끝나기 전에 새 탭을 누르면 `isFetchingFirstPage` 가드에 막혀
        // 새 요청이 통째로 버려지고 이전 탭 목록이 남는다. 취소 후 완료를 기다렸다가 이어간다.
        let previousTask = tabSwitchTask
        tabSwitchTask = Task { [weak self] in
            previousTask?.cancel()
            _ = await previousTask?.value
            await self?.fetchNotices()
        }
    }

    // MARK: - Fetch

    @MainActor
    func fetchNotices(page: Int = 0) async {
        guard let selectedTab else { return }

        if page == 0, hasNoAccessFromServer {
            hasNoAccessFromServer = false
            noticeItems = .loading
        }

        await performPagedFetch(page: page, tab: selectedTab) { request in
            try await self.noticeUseCase.getAllNotices(request: request)
        }
    }

    @MainActor
    func searchNotices(keyword: String, page: Int = 0) async {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            isSearchMode = false
            await fetchNotices()
            return
        }

        guard let selectedTab else { return }

        isSearchMode = true
        searchQuery = keyword
        await performPagedFetch(page: page, tab: selectedTab) { request in
            try await self.noticeUseCase.searchNotice(keyword: keyword, request: request)
        }
    }

    @MainActor
    func clearSearch() async {
        searchQuery = ""
        isSearchMode = false
        await fetchNotices()
    }

    @MainActor
    func retryCurrentRequest() async {
        if isSearchMode, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await searchNotices(keyword: searchQuery)
        } else {
            await fetchNotices()
        }
    }

    @MainActor
    func loadNextPageIfNeeded(currentItem: NoticeItemModel) async {
        guard case .loaded(let items) = noticeItems,
              let last = items.last,
              currentItem.id == last.id,
              pagingState.hasNextPage,
              !pagingState.isLoadingMore else {
            return
        }

        let nextPage = pagingState.nextPage
        if isSearchMode {
            await searchNotices(keyword: searchQuery, page: nextPage)
        } else {
            await fetchNotices(page: nextPage)
        }
    }

    // MARK: - Private

    @MainActor
    private func performPagedFetch(
        page: Int,
        tab: StaffNoticeTab,
        requestAction: (NoticeListRequest) async throws -> NoticePage
    ) async {
        if page == 0 {
            guard !isFetchingFirstPage else { return }
            isFetchingFirstPage = true
        }
        defer {
            if page == 0 {
                isFetchingFirstPage = false
            }
        }

        let previousState = noticeItems
        if page == 0, noticeItems.value == nil {
            noticeItems = .loading
        }

        guard pagingState.begin(page: page) else { return }

        let request = buildRequest(tab: tab, page: page)

        do {
            let response = try await requestAction(request)
            applyPagedResponse(response, page: page)
        } catch is CancellationError {
            handleCancelledFetch(page: page, previousState: previousState)
        } catch let error as NSError where error.domain == NSURLErrorDomain
            && error.code == NSURLErrorCancelled {
            handleCancelledFetch(page: page, previousState: previousState)
        } catch let error as RepositoryError {
            handleFetchError(
                .repository(error), page: page, action: "staffFetchNotices", failure: error
            )
        } catch let error as DomainError {
            handleFetchError(
                .domain(error), page: page, action: "staffFetchNotices", failure: error
            )
        } catch let error as NetworkError {
            handleFetchError(
                .network(error), page: page, action: "staffFetchNotices", failure: error
            )
        } catch {
            handleFetchError(
                .unknown(message: error.localizedDescription),
                page: page,
                action: "staffFetchNotices",
                failure: error
            )
        }
    }

    private func buildRequest(tab: StaffNoticeTab, page: Int) -> NoticeListRequest {
        // 지부장은 SCHOOL_CORE viewerRole로 매핑되어 학교 단위 필터 없이 조회한다.
        let needsSchoolId = tab.requiresSchoolId && memberRole != .chapterPresident
        let hasValidSchoolId = (Int(schoolId) ?? 0) > 0
        let resolvedSchoolId: String? = needsSchoolId && hasValidSchoolId ? schoolId : nil

        return NoticeListRequest(
            gisuId: gisuId,
            chapterId: nil,
            schoolId: resolvedSchoolId,
            part: nil,
            noticeTab: tab.rawValue,
            page: page,
            size: Pagination.pageSize,
            sort: Pagination.sort
        )
    }

    @MainActor
    private func applyPagedResponse(_ response: NoticePage, page: Int) {
        let readNoticeIDs = resolvedReadNoticeIDs()
        let items = response.items.map { item -> NoticeItemModel in
            guard readNoticeIDs.contains(item.noticeId) else { return item }
            return NoticeItemModel(
                noticeId: item.noticeId,
                generation: item.generation,
                scope: item.scope,
                category: item.category,
                mustRead: item.mustRead,
                isAlert: item.isAlert,
                date: item.date,
                title: item.title,
                content: item.content,
                writer: item.writer,
                authorNickname: item.authorNickname,
                authorName: item.authorName,
                links: item.links,
                images: item.images,
                vote: item.vote,
                viewCount: item.viewCount,
                scopeDisplayName: item.scopeDisplayName,
                targetsAllGenerations: item.targetsAllGenerations,
                parts: item.parts,
                isRead: true
            )
        }
        pagingState.applySuccess(page: page, hasNextPage: response.hasNext)

        if page == 0 {
            noticeItems = .loaded(items)
        } else {
            let mergedItems = (noticeItems.value ?? []) + items
            noticeItems = .loaded(mergedItems)
        }
    }

    private func resolvedReadNoticeIDs() -> Set<String> {
        let memberId = AppStorageKey.legacyMemberIdInt()
        guard memberId > 0 else { return [] }
        return (try? noticeReadRepository.fetchReadNoticeIDs(memberId: String(memberId))) ?? []
    }

    @MainActor
    private func handleFetchError(_ error: AppError, page: Int, action: String, failure: Error) {
        if case .network(.requestFailed(let statusCode, _)) = error, statusCode == 403 {
            hasNoAccessFromServer = true
            if page == 0 {
                noticeItems = .loaded([])
            }
            pagingState.applyFailure()
            return
        }

        if page == 0 {
            noticeItems = .failed(error)
        }
        pagingState.applyFailure()

        if case .domain = error { return }

        errorHandler.handle(
            failure,
            context: ErrorContext(feature: "StaffNotice", action: action)
        )
    }

    @MainActor
    private func handleCancelledFetch(page: Int, previousState: Loadable<[NoticeItemModel]>) {
        if page == 0 {
            noticeItems = previousState
        }
        pagingState.applyFailure()
    }
}
