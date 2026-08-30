//
//  CardExchangeItemDTOTests.swift
//  BusinessCardDataTests
//
//  Created by JEONG on 8/30/26.
//

import Foundation
import Testing
import UMCFoundation
import BusinessCardDomain
@testable import BusinessCardData

@Suite("CardExchangeItemDTO — 디코딩과 로컬 반영 규칙")
struct CardExchangeItemDTOTests {

    private func decode(_ json: String) throws -> CardExchangeItemDTO {
        try JSONDecoder().decode(CardExchangeItemDTO.self, from: Data(json.utf8))
    }

    /// 서버 `JacksonConfig` 가 숫자를 문자열로 직렬화한다. 설정이 바뀌어 숫자로 내려와도
    /// 흡수해야 한다 — 그때 앱이 통째로 빈 명함첩이 되면 안 된다.
    @Test("정수 필드는 문자열로도 숫자로도 읽힌다 (절대규칙 #2·#3)")
    func absorbsBothNumberShapes() throws {
        let asString = try decode("""
        {"cardMemberId":"42","name":"정의찬","nickname":"제옹","part":"IOS",
         "generation":"11","schoolName":"중앙대학교","source":"QR",
         "exchangedAt":"2026-08-30T01:02:03Z","isMutual":true}
        """)
        let asNumber = try decode("""
        {"cardMemberId":42,"name":"정의찬","nickname":"제옹","part":"IOS",
         "generation":11,"schoolName":"중앙대학교","source":"QR",
         "exchangedAt":"2026-08-30T01:02:03Z","isMutual":"true"}
        """)

        #expect(asString.cardMemberId == "42")
        #expect(asNumber.cardMemberId == "42")
        #expect(asNumber.generation == "11")
        #expect(asNumber.isMutual)
    }

    /// `email: null` 은 결측이 아니라 **값**이다. 상대가 나를 지웠다는 뜻이라 폴백하면 안 된다.
    @Test("email이 null이면 nil로 실려 온다")
    func nullEmailStaysNil() throws {
        let item = try decode("""
        {"cardMemberId":"42","name":"정의찬","nickname":"제옹","part":"IOS",
         "generation":"11","schoolName":"중앙대학교","email":null,"source":"QR",
         "exchangedAt":"2026-08-30T01:02:03Z","isMutual":false}
        """)

        #expect(item.email == nil)
        #expect(item.isMutual == false)
    }

    @Test("모르는 source는 unknown으로 흡수되고 올릴 때는 QR로 나간다")
    func unknownSourceRoundtrip() {
        #expect(ExchangeMethod(serverSource: "BULK") == .unknown)
        #expect(ExchangeMethod(serverSource: "nearby") == .nearby)
        #expect(ExchangeMethod.nearby.serverSourceValue == "NEARBY")
        #expect(ExchangeMethod.unknown.serverSourceValue == "QR")
    }

    /// 서버는 로컬 메모를 모른다. 재조정이 덮으면 사용자가 적은 것이 사라진다.
    @Test("서버 값 반영은 이메일을 덮고 로컬 메모·근거리 방식은 남긴다")
    func applyServerFieldsRespectsLocalOnlyValues() throws {
        let record = ReceivedCardRecord(
            ownerMemberId: "100", cardID: "CARD-42", memberId: "42",
            name: "옛이름", nickname: "옛닉", partRaw: "DESIGN", generation: "10",
            university: "중앙대학교", email: "before@umc.dev", github: nil,
            linkedIn: nil, blog: nil, avatarURL: nil, exchangedAt: Date(),
            exchangeContext: "OT에서 교환",
            exchangeMethodRaw: ExchangeMethod.nearby.rawValue
        )
        let item = try decode("""
        {"cardMemberId":"42","name":"정의찬","nickname":"제옹","part":"IOS",
         "generation":"11","schoolName":"중앙대학교","email":null,"source":"QR",
         "exchangedAt":"2026-08-30T01:02:03Z","isMutual":false}
        """)
        let syncedAt = Date()

        item.applyServerFields(to: record, syncedAt: syncedAt)

        #expect(record.email == nil)
        #expect(record.name == "정의찬")
        #expect(record.exchangeContext == "OT에서 교환")
        #expect(record.exchangeMethodRaw == ExchangeMethod.nearby.rawValue)
        #expect(record.serverSyncedAt == syncedAt)
    }
}
