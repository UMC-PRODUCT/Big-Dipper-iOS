//
//  MyActivePostsViewModel.swift
//  MyPage
//
//  Created by 김동민 on 7/13/26.
//

import Foundation
import UMCFoundation
import CoreDomain
import MyPageDomain

@Observable
public final class MyActivePostsViewModel {
    // MARK: - Property
    
    /// 사용자의 활동 내역 타입을 정의하는 열거형
    internal let logType: MyActiveLogsType
    private let useCaseProvider: MyPageUseCaseProviding
    
    public var postState: Loadable<[CommunityItemModel]> = .idle
    public var isLoadingMore: Bool = false
    
    private var currentPage: Int = 0
    private var hasNext: Bool = true
    private let pageSize: Int = 20
    private let sort: [String] = ["createdAt,DESC"]
    
    // MARK: - Function
    
    public init(
        logType: MyActiveLogsType,
        useCaseProvider: MyPageUseCaseProviding
    ) {
        self.logType = logType
        self.useCaseProvider = useCaseProvider
    }
    
    /// 초기화면만 fetch (필요시 사용)
    @MainActor
    public func fetchInitialIfNeeded() async {
        if case .loaded = postState {
            return
        }
        await fetchFirstPage()
    }
    
    
    /// 새로고침
    @MainActor
    public func refresh() async {
        await fetchFirstPage()
    }
    
    /// 로딩이 더 필요할 때 사용
    @MainActor
    public func loadMoreIfNeeded(currentItem: CommunityItemModel) async {
        guard case .loaded(let items) = postState,
              hasNext,
              !isLoadingMore,
              items.last?.id == currentItem.id else {
            return
        }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let nextPage = currentPage + 1
            let result = try await fetchPage(page: nextPage)
            currentPage = result.page
            hasNext = result.hasNext
            postState = .loaded(items + result.items)
        } catch {
            // 페이징 실패는 기존 목록 유지
        }
    }
}

private extension MyActivePostsViewModel {
    @MainActor
    private func fetchFirstPage() async {
        postState = .loading
        
        do {
            let result = try await fetchPage(page: 0)
            currentPage = result.page
            hasNext = result.hasNext
            postState = .loaded(result.items)
        } catch let error as AppError {
            postState = .failed(error)
        } catch {
            postState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }
    
    private func fetchPage(page: Int) async throws -> MyActivePostPage {
        let query = MyPagePostListQuery(
            page: page,
            size: pageSize,
            sort: sort
        )
        
        switch logType {
        case .myWritePost:
            return try await useCaseProvider.fetchMyPostsUseCase.execute(query: query)
        case .myWriteComment:
            return try await useCaseProvider.fetchMyCommentedPostsUseCase.execute(query: query)
        case .myScrapPost:
            return try await useCaseProvider.fetchMyScrappedPostsUseCase.execute(query: query)
        }
    }
}
