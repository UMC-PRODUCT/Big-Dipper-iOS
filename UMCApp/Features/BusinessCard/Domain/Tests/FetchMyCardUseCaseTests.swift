//
//  FetchMyCardUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import BusinessCardDomain

@Suite("FetchMyCardUseCase — Repository 위임")
struct FetchMyCardUseCaseTests {

    @Test("forceRefresh 인자를 그대로 위임하고 결과를 반환한다")
    func delegatesToRepository() async throws {
        let mock = MockBusinessCardRepository()
        let card = MyCard(
            memberId: "42", name: "정의찬", nickname: "제옹",
            part: .front(type: .ios), generation: "12", university: "한양대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
        )
        mock.fetchMyCardResult = .success(card)
        let sut = FetchMyCardUseCase(repository: mock)

        let result = try await sut.execute(forceRefresh: true)

        #expect(result == card)
        #expect(mock.fetchMyCardCallCount == 1)
        #expect(mock.lastForceRefresh == true)
    }

    @Test("Repository 에러를 그대로 던진다")
    func propagatesError() async {
        let sut = FetchMyCardUseCase(repository: MockBusinessCardRepository())

        await #expect(throws: MockError.self) {
            _ = try await sut.execute(forceRefresh: false)
        }
    }
}
