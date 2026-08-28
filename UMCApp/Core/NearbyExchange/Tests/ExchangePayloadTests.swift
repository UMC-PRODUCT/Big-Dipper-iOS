//
//  ExchangePayloadTests.swift
//  CoreNearbyExchangeTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import CoreNearbyExchange

@Suite("ExchangePayload v2 — 인코딩/디코딩·v1 하위호환·usdzURL 검증")
struct ExchangePayloadTests {

    /// `.iso8601` 전략은 분수 초를 버린다 — 기본값 `Date()`를 쓰면 라운드트립 후
    /// timestamp가 절삭되어 Equatable 비교가 깨진다. 정수 초를 명시 주입한다.
    private func makeV2() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
            name: "정의찬",
            nickname: "제옹",
            part: "IOS",
            generation: "12",
            university: "한양대학교",
            email: "one@umc.dev",
            github: "github.com/UMC-PRODUCT",
            linkedIn: "linkedin.com/in/umc",
            blog: nil,
            avatarURL: nil,
            cardLink: "umc://card/42",
            timestamp: Date(timeIntervalSince1970: 1_755_216_000)
        )
    }

    @Test("v2 라운드트립 — 인코딩 후 디코딩하면 동일하다")
    func v2Roundtrip() throws {
        let payload = try makeV2()

        let decoded = try ExchangePayload.decode(from: payload.jsonData())

        #expect(decoded == payload)
        #expect(decoded.version == ExchangePayload.currentVersion)
    }

    @Test("v1 JSON을 디코딩하면 ownerName이 name으로 매핑되고 나머지는 기본값이다")
    func v1BackwardCompatible() throws {
        let v1JSON = Data("""
        {"cardID":"abc","ownerName":"제옹","usdzURL":"https://cdn.umc.dev/card.usdz",
         "timestamp":"2026-04-23T00:00:00Z","version":1}
        """.utf8)

        let decoded = try ExchangePayload.decode(from: v1JSON)

        #expect(decoded.version == 1)
        #expect(decoded.name == "제옹")
        #expect(decoded.nickname == "")
        #expect(decoded.part == "")
        #expect(decoded.cardLink == "")
        #expect(decoded.usdzURL == URL(string: "https://cdn.umc.dev/card.usdz"))
    }

    @Test("모르는 상위 버전 페이로드는 조용히 v2로 읽지 않고 invalidPayload를 던진다")
    func rejectsFutureVersion() {
        let v3JSON = Data("""
        {"cardID":"abc","name":"제옹","nickname":"제옹","part":"IOS","generation":"12",
         "university":"한양대학교","cardLink":"umc://card?memberId=42",
         "timestamp":"2026-04-23T00:00:00Z","version":3}
        """.utf8)

        #expect(throws: NearbyError.self) {
            _ = try ExchangePayload.decode(from: v3JSON)
        }
    }

    @Test("usdzURL이 nil이면 통과한다 — 3D 에셋 없는 명함도 교환할 수 있다")
    func usdzURLOptional() throws {
        let payload = try makeV2()

        #expect(payload.usdzURL == nil)
    }

    @Test("usdzURL이 https가 아니면 invalidPayload를 던진다")
    func usdzURLRejectsInsecureScheme() {
        #expect(throws: NearbyError.self) {
            _ = try ExchangePayload(
                cardID: "abc", name: "제옹", nickname: "", part: "", generation: "",
                university: "", email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil,
                cardLink: "",
                usdzURL: URL(string: "http://insecure.example/card.usdz")
            )
        }
    }
}
