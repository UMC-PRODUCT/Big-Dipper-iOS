//
//  DeleteReceivedCardUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import BusinessCardDomain

@Suite("DeleteReceivedCardUseCase — id 위임·에러 전파")
struct DeleteReceivedCardUseCaseTests {

    @Test("전달한 id로 repository.delete를 호출한다")
    func delegatesId() async throws {
        let repository = MockReceivedCardRepository()
        let sut = DeleteReceivedCardUseCase(repository: repository)

        try await sut.execute(id: "CARD-1")

        #expect(repository.deletedIds == ["CARD-1"])
    }

    @Test("repository 에러를 그대로 전파한다")
    func propagatesError() async {
        let repository = MockReceivedCardRepository()
        repository.deleteError = MockError.notStubbed
        let sut = DeleteReceivedCardUseCase(repository: repository)

        await #expect(throws: MockError.self) {
            try await sut.execute(id: "CARD-1")
        }
    }
}
