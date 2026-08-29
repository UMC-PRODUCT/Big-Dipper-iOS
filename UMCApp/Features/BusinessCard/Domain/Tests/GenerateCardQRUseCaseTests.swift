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

@Suite("GenerateCardQRUseCase — 만료 링크 생성")
struct GenerateCardQRUseCaseTests {

    private let card = MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
    )

    /// QR 은 이미지로 저장·공유되어 손을 떠나므로 만료를 굽는다 (#1226). 앞부분은 Android 가
    /// 굽는 형식과 문자 그대로 같아야 저쪽 NavHost 패턴이 계속 매칭한다.
    @Test("명함 memberId로 만료가 붙은 링크를 만들어 생성기에 넘긴다")
    func bakesExpiringLink() throws {
        let generator = MockQRCodeGenerator()
        let sut = GenerateCardQRUseCase(generator: generator)

        _ = try sut.execute(for: card)

        let payload = try #require(generator.lastPayload)
        #expect(payload.hasPrefix("umc://card?memberId=42&exp="))
        #expect(generator.generateCallCount == 1)

        // 구운 문자열을 그대로 다시 읽어 상대 앱이 볼 값을 확인한다.
        let url = try #require(URL(string: payload))
        let parsed = try #require(CardLink.parse(url))
        #expect(parsed.memberId == "42")
        #expect(parsed.isExpired() == false)
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
