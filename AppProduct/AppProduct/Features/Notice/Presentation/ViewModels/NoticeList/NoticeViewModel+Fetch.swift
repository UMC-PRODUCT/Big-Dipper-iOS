//
//  NoticeViewModel+Fetch.swift
//  AppProduct
//
//  Created by euijjang97 on 2/17/26.
//

import Foundation

extension NoticeViewModel {

    // MARK: - Fetch

    /// 공지사항 목록 조회
    /// - Parameter page: 조회할 페이지 인덱스
    @MainActor
    func fetchNotices(page: Int = 0) async {
        await performPagedFetch(page: page) { request in
            try await self.noticeUseCase.getAllNotices(request: request)
        }
    }

    /// 공지사항 검색
    ///
    /// - Parameters:
    ///   - keyword: 검색어
    ///   - page: 조회할 페이지 인덱스
    @MainActor
    func searchNotices(keyword: String, page: Int = 0) async {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            isSearchMode = false
            await fetchNotices()
            return
        }

        isSearchMode = true
        searchQuery = keyword
        await performPagedFetch(page: page) { request in
            try await self.noticeUseCase.searchNotice(keyword: keyword, request: request)
        }
    }

    /// 검색 모드 해제 (일반 목록으로 복귀)
    @MainActor
    func clearSearch() async {
        searchQuery = ""
        isSearchMode = false
        await fetchNotices()
    }

    /// 현재 상태 기준으로 공지 조회를 재시도합니다.
    /// - Note: 기수 매핑이 비어 있으면 기수 목록부터 다시 로드합니다.
    @MainActor
    func retryCurrentRequest() async {
        if gisuPairs.isEmpty {
            fetchGisuList()
            return
        }

        if isSearchMode, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await searchNotices(keyword: searchQuery)
        } else {
            await fetchNotices()
        }
    }

    /// 리스트 마지막 셀 진입 시 다음 페이지 로드
    /// - Parameter currentItem: 화면에 노출된 현재 항목
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

    // MARK: - Private Function

    /// 페이징 조회 공통 로직 (기수 검증 → 요청 → 응답 반영)
    @MainActor
    private func performPagedFetch(
        page: Int,
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
        guard let gisuId = preparePagingAndResolveGisuId(page: page) else { return }

        do {
            let request = buildNoticeListRequest(gisuId: gisuId, page: page)
            let response = try await requestAction(request)
            await applyPagedResponse(response, page: page)
        } catch is CancellationError {
            handleCancelledFetch(page: page, previousState: previousState)
        } catch let error as NSError where isRequestCancellation(error) {
            handleCancelledFetch(page: page, previousState: previousState)
        } catch let error as RepositoryError {
            handleFetchError(.repository(error), page: page, action: "fetchNotices", failure: error)
        } catch let error as DomainError {
            handleFetchError(.domain(error), page: page, action: "fetchNotices", failure: error)
        } catch let error as NetworkError {
            handleFetchError(.network(error), page: page, action: "fetchNotices", failure: error)
        } catch {
            handleFetchError(
                .unknown(message: error.localizedDescription),
                page: page,
                action: "fetchNotices",
                failure: error
            )
        }
    }

    /// 페이지 상태를 준비하고 현재 선택된 기수의 gisuId를 반환합니다.
    /// - Parameter page: 요청 페이지
    /// - Returns: 조회 가능한 gisuId. 없으면 `nil`
    @MainActor
    private func preparePagingAndResolveGisuId(page: Int) -> Int? {
        if page == 0, noticeItems.value == nil {
            noticeItems = .loading
        }

        guard isGisuListLoaded, !gisuPairs.isEmpty else {
            if !isFetchingGisuList {
                fetchGisuList()
            }
            return nil
        }

        guard pagingState.begin(page: page) else { return nil }

        guard let gisuId = resolveCurrentGisuIdWithFallback() else {
            handleFetchError(
                .domain(.custom(message: "기수 정보를 불러오지 못했습니다.")),
                page: page,
                action: "fetchNotices",
                failure: DomainError.custom(message: "기수 정보를 불러오지 못했습니다.")
            )
            return nil
        }
        return gisuId
    }

    /// 현재 선택 기수의 gisuId를 우선 사용하고, 없으면 최신 기수로 보정합니다.
    @MainActor
    private func resolveCurrentGisuIdWithFallback() -> Int? {
        if let gisuId = currentSelectedGisuId(), gisuId > 0 {
            return gisuId
        }

        guard let fallback = gisuPairs
            .filter({ $0.gisuId > 0 })
            .max(by: { $0.gen < $1.gen }) else {
            return nil
        }

        selectedGeneration = Generation(value: fallback.gen)
        if generationStates[fallback.gen] == nil {
            generationStates[fallback.gen] = GenerationFilterState(mainFilter: .central)
        }
        return fallback.gisuId
    }

    /// 페이지 응답을 목록 상태에 반영합니다.
    /// - Parameters:
    ///   - response: 공지 페이징 응답 DTO
    ///   - page: 조회한 페이지 인덱스
    @MainActor
    private func applyPagedResponse(_ response: NoticePageDTO<NoticeDTO>, page: Int) async {
        #if DEBUG
        print(
            "[NoticeViewModel] applyPagedResponse " +
            "page=\(page) " +
            "contentCount=\(response.content.count) " +
            "totalElements=\(response.totalElements) " +
            "hasNext=\(response.hasNext)"
        )
        #endif

        if page == 0,
           response.content.isEmpty,
           (Int(response.totalElements) ?? 0) > 0 {
            let decodeError = RepositoryError.decodingError(
                detail: "공지 목록 응답 불일치: totalElements=\(response.totalElements), content=0"
            )

            handleFetchError(
                .repository(decodeError),
                page: page,
                action: "fetchNotices",
                failure: decodeError
            )
            return
        }

        let filteredContent = filteredNoticeDTOs(from: response.content)
        let branchNameOverrides = await resolveBranchNameOverrides(from: filteredContent)
        let readNoticeIDs = resolvedReadNoticeIDs()
        let items = filteredContent.map { dto in
            let chapterId = dto.targetInfo.targetChapterIdValue
            let scopeDisplayName = chapterId.flatMap { branchNameOverrides[$0] }
            let generation = resolvedGeneration(for: dto)
            let baseItem = dto.toItemModel(
                generationOverride: generation,
                scopeDisplayNameOverride: scopeDisplayName
            )

            guard readNoticeIDs.contains(dto.id) else {
                return baseItem
            }

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

    /// 현재 선택된 조회 필터에 맞지 않는 공지를 클라이언트 측에서 정리합니다.
    ///
    /// iOS-01은 서버-01, 서버-03만 노출하도록 후처리합니다.
    private func filteredNoticeDTOs(from notices: [NoticeDTO]) -> [NoticeDTO] {
        switch selectedMainFilter {
        case .central:
            return notices.filter { $0.targetInfo.isUMCWideGeneralNotice }
        case .all, .branch, .school, .part:
            return notices
        }
    }

    @MainActor
    private func resolveBranchNameOverrides(from notices: [NoticeDTO]) async -> [Int: String] {
        let missingBranchIds = Set(
            notices.compactMap { dto -> Int? in
                guard dto.targetInfo.resolvedScope == .branch else { return nil }
                guard dto.targetInfo.resolvedScopeDisplayName == nil else { return nil }
                return dto.targetInfo.targetChapterIdValue
            }
        )

        guard !missingBranchIds.isEmpty else { return [:] }

        var resolved: [Int: String] = [:]
        for chapterId in missingBranchIds {
            if let cached = chapterNameCache[chapterId] {
                resolved[chapterId] = cached
                continue
            }
            do {
                let chapterName = try await noticeEditorTargetUseCase.fetchBranchName(chapterId: chapterId)
                chapterNameCache[chapterId] = chapterName
                resolved[chapterId] = chapterName
            } catch {
                // 조회 실패 시 기본 칩 라벨(지부)로 fallback
                continue
            }
        }
        return resolved
    }

    private func resolvedGeneration(for dto: NoticeDTO) -> Int? {
        if let targetGisu = dto.targetInfo.targetGisu,
           let generation = Int(targetGisu),
           generation > 0 {
            return generation
        }

        guard let gisuId = Int(dto.targetInfo.targetGisuId), gisuId > 0 else {
            return nil
        }

        return gisuPairs.first(where: { $0.gisuId == gisuId })?.gen
    }

    private func resolvedReadNoticeIDs() -> Set<String> {
        guard currentMemberId > 0 else { return [] }
        return (try? noticeReadRepository.fetchReadNoticeIDs(memberId: currentMemberId)) ?? []
    }

    /// 조회 실패 상태를 반영합니다.
    /// - Parameters:
    ///   - error: 화면에 표시할 앱 에러
    ///   - page: 실패한 페이지 인덱스
    ///   - action: 에러 컨텍스트의 action 식별자
    ///   - failure: ErrorHandler에 전달할 원본 에러
    ///
    /// DomainError는 화면 인라인 에러(Loadable.failed)로만 표시해 Alert 중복을 방지합니다.
    /// 그 외 에러는 ErrorHandler를 통해 Alert 및 특수 케이스(자동 로그아웃 등) 흐름을 유지합니다.
    @MainActor
    private func handleFetchError(_ error: AppError, page: Int, action: String, failure: Error) {
        if page == 0 {
            noticeItems = .failed(error)
        }
        pagingState.applyFailure()

        if case .domain = error {
            return
        }

        errorHandler.handle(
            failure,
            context: ErrorContext(
                feature: "Notice",
                action: action
            )
        )
    }

    @MainActor
    private func handleCancelledFetch(page: Int, previousState: Loadable<[NoticeItemModel]>) {
        if page == 0 {
            noticeItems = previousState
        }
        pagingState.applyFailure()
    }

    private func isRequestCancellation(_ error: NSError) -> Bool {
        error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled
    }

    /// NoticeListRequestDTO 생성
    private func buildNoticeListRequest(gisuId: Int, page: Int) -> NoticeListRequestDTO {
        NoticeRequestFactory.make(
            gisuId: gisuId,
            page: page,
            selectedMainFilter: selectedMainFilter,
            chapterId: selectedGenerationChapterId,
            schoolId: selectedGenerationSchoolId,
            pageSize: pageSize,
            sort: pageSort
        )
    }
}
