//
//  FetchMyPostsUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("FetchMyPostsUseCase — Repository 위임 검증")
struct FetchMyPostsUseCaseTests {

    @Test("execute(query:) 호출 시 repository.fetchMyPosts(query:)에 쿼리를 그대로 넘기고 결과를 반환한다")
    func delegatesToFetchMyPosts() async throws {
        let query = MyPagePostListQuery(page: 3, size: 5, sort: ["custom,ASC"])
        let expected = MyActivePostPage(items: [], page: 7, hasNext: true)
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .success(expected)
        let useCase = FetchMyPostsUseCase(repository: mock)

        let result = try await useCase.execute(query: query)

        #expect(result == expected)
        #expect(mock.fetchMyPostsCallCount == 1)
        #expect(mock.fetchMyPostsReceivedQuery == query)
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.fetchMyPostsResult = .failure(MyPageTestError.boom)
        let useCase = FetchMyPostsUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            _ = try await useCase.execute(query: MyPagePostListQuery())
        }
    }
}
