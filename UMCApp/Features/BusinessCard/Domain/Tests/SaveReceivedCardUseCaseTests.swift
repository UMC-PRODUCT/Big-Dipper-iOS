//
//  SaveReceivedCardUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import CoreNearbyExchange
@testable import BusinessCardDomain

@Suite("SaveReceivedCardUseCase — 페이로드 변환 후 저장 위임")
struct SaveReceivedCardUseCaseTests {

    private func makePayload() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "CARD-PEER", name: "상대", nickname: "상대닉", part: "DESIGN",
            generation: "11", university: "중앙대학교", email: nil, github: nil,
            linkedIn: nil, blog: nil, avatarURL: nil, cardLink: "umc://card/7"
        )
    }

    @Test("페이로드를 ReceivedCard로 변환해 저장하고 그 값을 반환한다")
    func convertsAndSaves() async throws {
        let repository = MockReceivedCardRepository()
        let sut = SaveReceivedCardUseCase(repository: repository)

        let saved = try await sut.execute(
            payload: try makePayload(),
            exchangeContext: "OT에서 교환"
        )

        #expect(saved.id == "CARD-PEER")
        #expect(saved.profile.memberId == "7")
        #expect(saved.exchangeContext == "OT에서 교환")
        #expect(repository.savedCards.count == 1)
        #expect(repository.savedCards.first?.id == "CARD-PEER")
    }

    @Test("저장 실패는 그대로 전파한다")
    func propagatesSaveError() async throws {
        let repository = MockReceivedCardRepository()
        repository.saveError = MockError.notStubbed
        let sut = SaveReceivedCardUseCase(repository: repository)
        let payload = try makePayload()

        await #expect(throws: MockError.self) {
            _ = try await sut.execute(payload: payload, exchangeContext: nil)
        }
    }
}
