//
//  FetchReceivedCardsUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import BusinessCardDomain

@Suite("FetchReceivedCardsUseCase — 질의 유무에 따른 경로 분기")
struct FetchReceivedCardsUseCaseTests {

    private func makeCard(id: String) -> ReceivedCard {
        ReceivedCard(
            id: id,
            profile: MyCard(
                memberId: "7", name: "상대", nickname: "상대닉",
                part: .admin, generation: "11", university: "중앙대학교",
                email: nil, github: nil, blog: nil, avatarURL: nil
            ),
            exchangedAt: Date(timeIntervalSince1970: 0),
            exchangeContext: nil,
            isConnected: false
        )
    }

    @Test("query가 nil이면 전체 목록을 조회한다")
    func nilQueryFetchesAll() async throws {
        let repository = MockReceivedCardRepository()
        repository.fetchAllResult = .success([makeCard(id: "CARD-1")])
        let sut = FetchReceivedCardsUseCase(repository: repository)

        let result = try await sut.execute(query: nil)

        #expect(result.count == 1)
        #expect(repository.fetchAllCallCount == 1)
        #expect(repository.lastSearchQuery == nil)
    }

    @Test("query가 공백뿐이면 전체 목록을 조회한다")
    func blankQueryFetchesAll() async throws {
        let repository = MockReceivedCardRepository()
        let sut = FetchReceivedCardsUseCase(repository: repository)

        _ = try await sut.execute(query: "   ")

        #expect(repository.fetchAllCallCount == 1)
        #expect(repository.lastSearchQuery == nil)
    }

    @Test("query가 있으면 검색에 위임한다")
    func nonBlankQuerySearches() async throws {
        let repository = MockReceivedCardRepository()
        repository.searchResult = .success([makeCard(id: "CARD-2")])
        let sut = FetchReceivedCardsUseCase(repository: repository)

        let result = try await sut.execute(query: "제옹")

        #expect(result.first?.id == "CARD-2")
        #expect(repository.lastSearchQuery == "제옹")
        #expect(repository.fetchAllCallCount == 0)
    }
}
