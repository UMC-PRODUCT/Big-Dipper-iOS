//
//  MyCardExchangePayloadTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import UMCFoundation
import CoreNearbyExchange
@testable import BusinessCardDomain

@Suite("MyCard ↔ ExchangePayload 매핑")
struct MyCardExchangePayloadTests {

    private let card = MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: "one@umc.dev", github: "github.com/UMC-PRODUCT",
        linkedIn: "linkedin.com/in/umc", blog: nil,
        avatarURL: nil
    )

    @Test("명함 → 페이로드 → 명함 왕복에서 정체성 필드가 보존된다")
    func roundtrip() throws {
        let payload = try card.toExchangePayload()

        let restored = MyCard(payload: payload)

        #expect(restored.memberId == "42")
        #expect(restored.name == "정의찬")
        #expect(restored.part == .front(type: .ios))
        #expect(restored.generation == "12")
        #expect(restored.linkedIn == "linkedin.com/in/umc")
        #expect(payload.linkedIn == "linkedin.com/in/umc")
        #expect(payload.cardLink == CardLink(memberId: "42").urlString)
        #expect(payload.version == ExchangePayload.currentVersion)
    }

    @Test("파싱 불가한 part는 admin으로 폴백한다 (정본 매핑과 동일 규칙)")
    func unknownPartFallsBackToAdmin() throws {
        let payload = try ExchangePayload(
            cardID: "abc", name: "제옹", nickname: "", part: "정체불명",
            generation: "12", university: "", email: nil, github: nil, linkedIn: nil, blog: nil,
            avatarURL: nil, cardLink: "umc://card/7"
        )

        let card = MyCard(payload: payload)

        // 열거형 값은 관례대로 `.admin` 이지만, 화면·전송은 원본을 쓴다. 상대가 다른
        // 플랫폼일 수 있어 「모르는 파트」를 「운영진」으로 바꿔 보여주면 안 된다.
        #expect(card.part == .admin)
        #expect(card.partRaw == "정체불명")
        #expect(card.partDisplayName == "정체불명")
        #expect(card.partAPIValue == "정체불명")
    }

    @Test("파트가 비어 있으면 진짜로 파트가 없는 것이라 원본을 남기지 않는다")
    func blankPartKeepsAdminWithoutRaw() throws {
        let payload = try ExchangePayload(
            cardID: "abc", name: "제옹", nickname: "", part: "  ",
            generation: "12", university: "", email: nil, github: nil, linkedIn: nil, blog: nil,
            avatarURL: nil, cardLink: "umc://card/7"
        )

        let card = MyCard(payload: payload)

        #expect(card.part == .admin)
        #expect(card.partRaw == nil)
        #expect(card.partDisplayName == UMCPartType.admin.name)
    }

    @Test("못 읽은 파트는 되보낼 때도 원본 그대로다 — ADMIN 으로 바꿔 퍼뜨리지 않는다")
    func unknownPartRoundTripsUnchanged() throws {
        let payload = try ExchangePayload(
            cardID: "abc", name: "제옹", nickname: "", part: "RUST",
            generation: "12", university: "", email: nil, github: nil, linkedIn: nil, blog: nil,
            avatarURL: nil, cardLink: "umc://card/7"
        )

        let resent = try MyCard(payload: payload).toExchangePayload()

        #expect(resent.part == "RUST")
    }

    @Test("페이로드에서 ReceivedCard를 만들면 cardID가 id가 된다")
    func receivedCardFromPayload() throws {
        let payload = try card.toExchangePayload(cardID: "CARD-1")

        let received = ReceivedCard(payload: payload, exchangeContext: "OT에서 교환")

        #expect(received.id == "CARD-1")
        #expect(received.profile.name == "정의찬")
        #expect(received.exchangeContext == "OT에서 교환")
    }
}
