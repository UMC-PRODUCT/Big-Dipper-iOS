//
//  MPCDiscoveryInfoTests.swift
//  CoreNearbyExchangeTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import CoreNearbyExchange

/// 발견 광고에 싣는 정보의 계약.
///
/// 시안(Figma 12654:32621)의 행은 **명함을 받기 전에** 이름·파트·기수를 보여준다. 그 값이
/// 여기서 나온다. 동시에 이건 **동의 없이 주변에 뿌려지는 정보**라 최소여야 한다 —
/// 편의상 필드를 늘리면 명함을 안 줬는데도 이메일이 새어 나간다.
@Suite("MPC discoveryInfo — 발견 광고 계약")
struct MPCDiscoveryInfoTests {

    private func makeCard(
        name: String = "정의찬",
        nickname: String = "제옹",
        avatarURL: String? = "https://cdn.umc.it.kr/a.png"
    ) throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "CARD-1",
            name: name,
            nickname: nickname,
            part: "IOS",
            generation: "12",
            university: "한양대학교",
            email: "one@umc.it.kr",
            github: "https://github.com/one",
            linkedIn: "https://linkedin.com/in/one",
            blog: "https://blog.one",
            avatarURL: avatarURL,
            cardLink: "https://api.university.neordinary.com/mypage/card?memberId=42"
        )
    }

    @Test("시안 행에 필요한 값이 모두 실린다")
    func carriesFieldsTheDesignNeeds() throws {
        let info = MPCTransport.discoveryInfo(from: try makeCard(), sessionID: "abc123")

        #expect(info["n"] == "정의찬")
        #expect(info["k"] == "제옹")
        #expect(info["p"] == "IOS")
        #expect(info["g"] == "12")
        #expect(info["a"] == "https://cdn.umc.it.kr/a.png")
    }

    @Test("이메일·외부 링크·딥링크는 실리지 않는다 — 동의 전에 뿌려지는 정보다")
    func omitsPrivateFields() throws {
        let values = MPCTransport.discoveryInfo(from: try makeCard(), sessionID: "abc123").values.joined()

        #expect(!values.contains("one@umc.it.kr"))
        #expect(!values.contains("github.com"))
        #expect(!values.contains("linkedin.com"))
        #expect(!values.contains("blog.one"))
        #expect(!values.contains("memberId"))
    }

    @Test("아바타가 없으면 키 자체를 넣지 않는다 — TXT 레코드 낭비를 막는다")
    func omitsEmptyAvatar() throws {
        let withoutAvatar = MPCTransport.discoveryInfo(from: try makeCard(avatarURL: nil), sessionID: "abc123")
        let withEmpty = MPCTransport.discoveryInfo(from: try makeCard(avatarURL: ""), sessionID: "abc123")

        #expect(withoutAvatar["a"] == nil)
        #expect(withEmpty["a"] == nil)
    }

    @Test("긴 값은 잘린다 — Bonjour TXT 레코드는 작다")
    func truncatesLongValues() throws {
        let long = String(repeating: "가", count: 200)
        let info = MPCTransport.discoveryInfo(from: try makeCard(name: long), sessionID: "abc123")

        let name = try #require(info["n"])
        #expect(name.count == 64)
    }

    @Test("세션 식별자가 실린다 — 이게 없으면 피어를 구분할 수 없다")
    func carriesSessionID() throws {
        let info = MPCTransport.discoveryInfo(from: try makeCard(), sessionID: "abc123")

        #expect(info["s"] == "abc123")
    }

    @Test("서비스 타입이 MPC 규칙을 지킨다 — 15자 이하·영숫자와 하이픈만")
    func serviceTypeIsValid() {
        let type = MPCTransport.serviceType

        #expect(type.count <= 15)
        #expect(!type.isEmpty)
        #expect(!type.hasPrefix("-"))
        #expect(!type.hasSuffix("-"))
        #expect(type.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" })
    }
}
