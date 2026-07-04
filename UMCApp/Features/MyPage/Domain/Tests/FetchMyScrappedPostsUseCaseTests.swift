//
//  FetchMyScrappedPostsUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("FetchMyScrappedPostsUseCase — Repository 위임 검증")
struct FetchMyScrappedPostsUseCaseTests {

    @Test("execute(query:) 호출 시 repository.fetchScrappedPosts(query:)에 쿼리를 그대로 넘기고 결과를 반환한다")
    func delegatesToFetchScrappedPosts() async throws {
        let query = MyPagePostListQuery(page: 1, size: 30, sort: ["createdAt,ASC"])
        let expected = MyActivePostPage(items: [], page: 1, hasNext: true)
        let mock = MockMyPageRepository()
        mock.fetchScrappedPostsResult = .success(expected)
        let useCase = FetchMyScrappedPostsUseCase(repository: mock)

        let result = try await useCase.execute(query: query)

        #expect(result == expected)
        #expect(mock.fetchScrappedPostsCallCount == 1)
        #expect(mock.fetchScrappedPostsReceivedQuery == query)
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.fetchScrappedPostsResult = .failure(MyPageTestError.boom)
        let useCase = FetchMyScrappedPostsUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            _ = try await useCase.execute(query: MyPagePostListQuery())
        }
    }
}
