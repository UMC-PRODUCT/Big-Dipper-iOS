//
//  MyCardTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import BusinessCardDomain

@Suite("MyCard — 파생 프로퍼티")
struct MyCardTests {

    @Test("qrPayload는 cardLink urlString과 항상 같다 (MP-F02·F04 동일 페이로드)")
    func qrPayloadEqualsCardLink() {
        let card = MyCard(
            memberId: "42", name: "정의찬", nickname: "제옹",
            part: .front(type: .ios), generation: "12", university: "한양대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
        )

        #expect(card.qrPayload == "umc://card/42")
        #expect(card.qrPayload == card.cardLink.urlString)
    }
}
