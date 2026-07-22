//
//  MyActivePostsViewModelTests.swift
//  MyPagePresentationTests
//
//  Created by 김동민 on 7/13/26.
//

import Testing
import Foundation
import UMCFoundation
import CoreDomain
import MyPageDomain
@testable import MyPagePresentation

@MainActor
@Suite("MyActivePostsViewModel — 페이지네이션 및 logType 라우팅")
struct MyActivePostsViewModelTests {

    // MARK: - 초기 상태

    @Test("초기 상태는 .idle")
    func initialStateIsIdle() {
        let viewModel = makeViewModel(logType: .myWritePost, repository: MockMyPageRepository())
        #expect(viewModel.postState == .idle)
        #expect(viewModel.isLoadingMore == false)
    }

    // MARK: - 첫 페이지 로드

    @Test("fetchInitialIfNeeded 성공 시 .loaded + 쿼리는 page 0 / size 20 / createdAt,DESC")
    func fetchInitialSuccessLoadsFirstPage() async {
        let items = [makeStubCommunityItem(postId: "1"), makeStubCommunityItem(postId: "2")]
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: items, page: 0, hasNext: true))
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()

        guard case .loaded(let loaded) = viewModel.postState else {
            Issue.record("Expected .loaded, got \(viewModel.postState)")
            return
        }
        #expect(loaded == items)
        #expect(mock.fetchMyPostsCallCount == 1)
        #expect(mock.fetchMyPostsReceivedQuery?.page == 0)
        #expect(mock.fetchMyPostsReceivedQuery?.size == 20)
        #expect(mock.fetchMyPostsReceivedQuery?.sort == ["createdAt,DESC"])
    }

    @Test(
        "logType은 대응하는 repository 메서드만 정확히 1회 호출",
        arguments: MyActiveLogsType.allCases
    )
    func logTypeRoutesToMatchingUseCase(logType: MyActiveLogsType) async {
        let mock = MockMyPageRepository()
        // 세 경로 모두 스텁해 두고, 실제로 호출된 경로만 카운터로 판별
        let page = makeStubPostPage(items: [makeStubCommunityItem(postId: "1")])
        mock.fetchMyPostsResult = .success(page)
        mock.fetchCommentedPostsResult = .success(page)
        mock.fetchScrappedPostsResult = .success(page)
        let viewModel = makeViewModel(logType: logType, repository: mock)

        await viewModel.fetchInitialIfNeeded()

        for counter in MyActivePostFetchCounter.allCases {
            #expect(mock[keyPath: counter.callCountKeyPath] == (counter == .expected(for: logType) ? 1 : 0))
        }
    }

    @Test("이미 .loaded면 fetchInitialIfNeeded는 재요청하지 않음")
    func fetchInitialSkipsWhenAlreadyLoaded() async {
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: [makeStubCommunityItem(postId: "1")]))
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()
        await viewModel.fetchInitialIfNeeded()

        #expect(mock.fetchMyPostsCallCount == 1)
    }

    @Test("refresh는 .loaded 상태여도 첫 페이지를 다시 조회")
    func refreshAlwaysReloadsFirstPage() async {
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: [makeStubCommunityItem(postId: "1")], page: 0))
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()
        await viewModel.refresh()

        #expect(mock.fetchMyPostsCallCount == 2)
        #expect(mock.fetchMyPostsReceivedQuery?.page == 0)
    }

    // MARK: - 첫 페이지 에러

    @Test("AppError 발생 시 .failed(error)로 전이")
    func appErrorPropagatesToFailed() async {
        let error = AppError.unknown(message: "boom")
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .failure(error)
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()

        #expect(viewModel.postState.error == error)
    }

    @Test("일반 Error 발생 시 .failed(.unknown)으로 래핑")
    func genericErrorWrappedAsUnknown() async {
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .failure(MyPageTestError.boom)
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()

        guard case .failed(let appError) = viewModel.postState,
              case .unknown = appError else {
            Issue.record("Expected .failed(.unknown), got \(viewModel.postState)")
            return
        }
    }

    // MARK: - loadMoreIfNeeded

    @Test("마지막 아이템 도달 + hasNext면 다음 페이지를 append하고 page/hasNext 갱신")
    func loadMoreAppendsNextPage() async {
        let firstItems = [makeStubCommunityItem(postId: "1"), makeStubCommunityItem(postId: "2")]
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: firstItems, page: 0, hasNext: true))
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()
        guard case .loaded(let loaded) = viewModel.postState, let last = loaded.last else {
            Issue.record("첫 페이지 로드 실패")
            return
        }

        // 두 번째 페이지 응답으로 교체 (hasNext=false로 종료)
        let secondItems = [makeStubCommunityItem(postId: "3")]
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: secondItems, page: 1, hasNext: false))

        await viewModel.loadMoreIfNeeded(currentItem: last)

        guard case .loaded(let merged) = viewModel.postState else {
            Issue.record("Expected .loaded after loadMore")
            return
        }
        #expect(merged == firstItems + secondItems)
        #expect(mock.fetchMyPostsCallCount == 2)
        #expect(mock.fetchMyPostsReceivedQuery?.page == 1)
        #expect(viewModel.isLoadingMore == false)
    }

    @Test("마지막 아이템이 아니면 loadMore는 무시")
    func loadMoreIgnoredWhenNotLastItem() async {
        let firstItems = [makeStubCommunityItem(postId: "1"), makeStubCommunityItem(postId: "2")]
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: firstItems, page: 0, hasNext: true))
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()

        // 로드된 목록에 없는 별개 아이템 → guard 실패
        await viewModel.loadMoreIfNeeded(currentItem: makeStubCommunityItem(postId: "999"))

        #expect(mock.fetchMyPostsCallCount == 1)
    }

    @Test("hasNext=false면 마지막 아이템이어도 loadMore는 무시")
    func loadMoreIgnoredWhenNoNextPage() async {
        let items = [makeStubCommunityItem(postId: "1")]
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: items, page: 0, hasNext: false))
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()
        guard case .loaded(let loaded) = viewModel.postState, let last = loaded.last else {
            Issue.record("첫 페이지 로드 실패")
            return
        }

        await viewModel.loadMoreIfNeeded(currentItem: last)

        #expect(mock.fetchMyPostsCallCount == 1)
    }

    @Test("페이징 실패 시 기존 목록을 그대로 유지")
    func loadMoreFailureKeepsExistingItems() async {
        let firstItems = [makeStubCommunityItem(postId: "1")]
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(makeStubPostPage(items: firstItems, page: 0, hasNext: true))
        let viewModel = makeViewModel(logType: .myWritePost, repository: mock)

        await viewModel.fetchInitialIfNeeded()
        guard case .loaded(let loaded) = viewModel.postState, let last = loaded.last else {
            Issue.record("첫 페이지 로드 실패")
            return
        }

        mock.fetchMyPostsResult = .failure(MyPageTestError.boom)
        await viewModel.loadMoreIfNeeded(currentItem: last)

        guard case .loaded(let stillLoaded) = viewModel.postState else {
            Issue.record("Expected list preserved as .loaded")
            return
        }
        #expect(stillLoaded == firstItems)
        #expect(viewModel.isLoadingMore == false)
    }
}

// MARK: - Helpers

/// `MyActiveLogsType` → repository 호출 카운터 대응표.
///
/// `MyActiveLogsType`에 케이스가 추가되면 `expected(for:)`의 switch가 컴파일 에러를 내므로,
/// 새 케이스의 기대 라우팅을 반드시 정의하게 됩니다.
private enum MyActivePostFetchCounter: CaseIterable {
    case myPosts
    case commentedPosts
    case scrappedPosts

    var callCountKeyPath: KeyPath<MockMyPageRepository, Int> {
        switch self {
        case .myPosts: \.fetchMyPostsCallCount
        case .commentedPosts: \.fetchCommentedPostsCallCount
        case .scrappedPosts: \.fetchScrappedPostsCallCount
        }
    }

    static func expected(for logType: MyActiveLogsType) -> Self {
        switch logType {
        case .myWritePost: .myPosts
        case .myWriteComment: .commentedPosts
        case .myScrapPost: .scrappedPosts
        }
    }
}

@MainActor
private func makeViewModel(
    logType: MyActiveLogsType,
    repository: MockMyPageRepository
) -> MyActivePostsViewModel {
    MyActivePostsViewModel(
        logType: logType,
        useCaseProvider: makeUseCaseProvider(repository)
    )
}
