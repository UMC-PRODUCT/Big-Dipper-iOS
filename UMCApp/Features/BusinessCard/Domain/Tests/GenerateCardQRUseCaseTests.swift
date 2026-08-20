//
//  GenerateCardQRUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import BusinessCardDomain

@Suite("GenerateCardQRUseCase — qrPayload 전달")
struct GenerateCardQRUseCaseTests {

    private let card = MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
    )

    @Test("명함의 qrPayload를 생성기에 그대로 넘긴다")
    func passesQRPayload() throws {
        let generator = MockQRCodeGenerator()
        let sut = GenerateCardQRUseCase(generator: generator)

        _ = try sut.execute(for: card)

        #expect(generator.lastPayload == CardLink(memberId: "42").urlString)
        #expect(generator.generateCallCount == 1)
    }

    @Test("생성기 에러를 그대로 전파한다")
    func propagatesError() {
        let generator = MockQRCodeGenerator()
        generator.generateError = MockError.notStubbed
        let sut = GenerateCardQRUseCase(generator: generator)

        #expect(throws: MockError.self) {
            _ = try sut.execute(for: card)
        }
    }
}
