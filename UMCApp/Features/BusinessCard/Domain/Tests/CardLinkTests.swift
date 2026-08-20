//
//  CardLinkTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import BusinessCardDomain

@Suite("CardLink — 생성·파싱 왕복")
struct CardLinkTests {

    @Test("urlString은 umc://card/{memberId} 형식이다")
    func urlStringFormat() {
        #expect(CardLink(memberId: "42").urlString == "umc://card/42")
    }

    @Test("생성한 URL을 다시 파싱하면 같은 memberId가 나온다")
    func roundtrip() throws {
        let link = CardLink(memberId: "42")

        let parsed = CardLink.parse(try #require(link.url))

        #expect(parsed?.memberId == "42")
    }

    @Test("다른 스킴·다른 host·빈 id·허용 밖 문자는 nil", arguments: [
        "https://card/42", "umc://thread/42", "umc://card/", "umc://card/4 2",
    ])
    func rejectsInvalid(urlString: String) throws {
        let url = try #require(URL(string: urlString.replacingOccurrences(of: " ", with: "%20")))

        #expect(CardLink.parse(url) == nil)
    }
}
