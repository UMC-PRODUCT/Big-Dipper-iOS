//
//  StaffNoticeViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/15/26.
//

import Foundation
import SwiftUI

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
    private(set) var schoolId: Int = 0
    private(set) var gisuId: Int = 0

    private(set) var accessibleTabs: [StaffNoticeTab] = []
    var selectedTab: StaffNoticeTab?

    var noticeItems: Loadable<[NoticeItemModel]> = .idle
    var pagingState = NoticePagingState()

    var isSearchMode: Bool = false
    var searchQuery: String = ""

    let errorHandler: ErrorHandler

    private var isFetchingFirstPage: Bool = false

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
        schoolId: Int,
        gisuId: Int
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
        guard accessibleTabs.contains(tab) else { return }
        selectedTab = tab
        isSearchMode = false
        searchQuery = ""
        Task {
            await fetchNotices()
        }
    }

    // MARK: - Fetch

    @MainActor
    func fetchNotices(page: Int = 0) async {
        guard let selectedTab else { return }

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
        requestAction: (NoticeListRequestDTO) async throws -> NoticePageDTO<NoticeDTO>
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
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            handleCancelledFetch(page: page, previousState: previousState)
        } catch let error as RepositoryError {
            handleFetchError(.repository(error), page: page, action: "staffFetchNotices", failure: error)
        } catch let error as DomainError {
            handleFetchError(.domain(error), page: page, action: "staffFetchNotices", failure: error)
        } catch let error as NetworkError {
            handleFetchError(.network(error), page: page, action: "staffFetchNotices", failure: error)
        } catch {
            handleFetchError(
                .unknown(message: error.localizedDescription),
                page: page,
                action: "staffFetchNotices",
                failure: error
            )
        }
    }

    private func buildRequest(tab: StaffNoticeTab, page: Int) -> NoticeListRequestDTO {
        NoticeListRequestDTO(
            gisuId: gisuId,
            schoolId: tab.requiresSchoolId ? (schoolId > 0 ? schoolId : nil) : nil,
            noticeTab: tab.rawValue,
            page: page,
            size: Pagination.pageSize,
            sort: Pagination.sort
        )
    }

    @MainActor
    private func applyPagedResponse(_ response: NoticePageDTO<NoticeDTO>, page: Int) {
        let readNoticeIDs = resolvedReadNoticeIDs()
        let items = response.content.map { dto in
            let baseItem = dto.toItemModel()
            guard readNoticeIDs.contains(dto.id) else { return baseItem }
            return NoticeItemModel(
                noticeId: baseItem.noticeId,
                generation: baseItem.generation,
                scope: baseItem.scope,
                category: baseItem.category,
                mustRead: baseItem.mustRead,
                isAlert: baseItem.isAlert,
                date: baseItem.date,
                title: baseItem.title,
                content: baseItem.content,
                writer: baseItem.writer,
                authorNickname: baseItem.authorNickname,
                authorName: baseItem.authorName,
                links: baseItem.links,
                images: baseItem.images,
                vote: baseItem.vote,
                viewCount: baseItem.viewCount,
                scopeDisplayName: baseItem.scopeDisplayName,
                targetsAllGenerations: baseItem.targetsAllGenerations,
                parts: baseItem.parts,
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
        return (try? noticeReadRepository.fetchReadNoticeIDs(memberId: memberId)) ?? []
    }

    @MainActor
    private func handleFetchError(_ error: AppError, page: Int, action: String, failure: Error) {
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
