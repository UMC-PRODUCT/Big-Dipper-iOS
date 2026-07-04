//
//  FetchMyCommentedPostsUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("FetchMyCommentedPostsUseCase — Repository 위임 검증")
struct FetchMyCommentedPostsUseCaseTests {

    @Test("execute(query:) 호출 시 repository.fetchCommentedPosts(query:)에 쿼리를 그대로 넘기고 결과를 반환한다")
    func delegatesToFetchCommentedPosts() async throws {
        let query = MyPagePostListQuery(page: 2, size: 10, sort: ["likeCount,DESC"])
        let expected = MyActivePostPage(items: [], page: 4, hasNext: false)
        let mock = MockMyPageRepository()
        mock.fetchCommentedPostsResult = .success(expected)
        let useCase = FetchMyCommentedPostsUseCase(repository: mock)

        let result = try await useCase.execute(query: query)

        #expect(result == expected)
        #expect(mock.fetchCommentedPostsCallCount == 1)
        #expect(mock.fetchCommentedPostsReceivedQuery == query)
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.fetchCommentedPostsResult = .failure(MyPageTestError.boom)
        let useCase = FetchMyCommentedPostsUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            _ = try await useCase.execute(query: MyPagePostListQuery())
        }
    }
}
