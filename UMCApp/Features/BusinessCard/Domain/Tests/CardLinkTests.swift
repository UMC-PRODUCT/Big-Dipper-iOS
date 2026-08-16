//
//  CardLinkTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import BusinessCardDomain

/// 명함 딥링크는 **Android·서버와 합의한 크로스 플랫폼 계약**이다. 두 앱이 같은 QR 을
/// 읽어야 하므로 형식이 바뀌면 여기서 먼저 깨져야 한다.
@Suite("CardLink — Universal Link 생성·파싱")
struct CardLinkTests {

    @Test("urlString은 합의된 Universal Link 형식이다 — /mypage/card?memberId=")
    func urlStringFormat() {
        let urlString = CardLink(memberId: "42").urlString

        #expect(urlString.hasPrefix("https://"))
        #expect(urlString.hasSuffix("/mypage/card?memberId=42"))
        #expect(urlString.contains("api.university.neordinary.com"))
    }

    @Test("생성한 URL을 다시 파싱하면 같은 memberId가 나온다")
    func roundtrip() throws {
        let link = CardLink(memberId: "42")

        let parsed = CardLink.parse(try #require(link.url))

        #expect(parsed?.memberId == "42")
    }

    @Test("운영·alpha 호스트를 모두 받는다 — alpha 빌드 QR을 운영 빌드로 스캔하는 경우", arguments: [
        "https://api.university.neordinary.com/mypage/card?memberId=42",
        "https://alpha.api.university.neordinary.com/mypage/card?memberId=42",
    ])
    func acceptsBothHosts(urlString: String) throws {
        let url = try #require(URL(string: urlString))

        #expect(CardLink.parse(url)?.memberId == "42")
    }

    @Test("다른 쿼리가 섞여 있어도 memberId를 찾는다")
    func toleratesExtraQueryItems() throws {
        let url = try #require(URL(
            string: "https://api.university.neordinary.com/mypage/card?utm=qr&memberId=42"
        ))

        #expect(CardLink.parse(url)?.memberId == "42")
    }

    @Test("커스텀 스킴 umc://card/{id}도 계속 읽는다 — Android가 먼저 검증한 형식")
    func stillReadsCustomScheme() throws {
        let url = try #require(URL(string: "umc://card/42"))

        #expect(CardLink.parse(url)?.memberId == "42")
    }

    @Test("호스트·경로·쿼리가 어긋나면 nil", arguments: [
        // 남의 호스트
        "https://evil.com/mypage/card?memberId=42",
        // 경로 다름 (커뮤니티 스레드 링크)
        "https://api.university.neordinary.com/community/threads/42",
        // memberId 쿼리 없음
        "https://api.university.neordinary.com/mypage/card?id=42",
        // 빈 값
        "https://api.university.neordinary.com/mypage/card?memberId=",
        // 허용 밖 문자
        "https://api.university.neordinary.com/mypage/card?memberId=4%202",
        // 커스텀 스킴이지만 host가 다름
        "umc://thread/42",
        "umc://card/",
    ])
    func rejectsInvalid(urlString: String) throws {
        let url = try #require(URL(string: urlString))

        #expect(CardLink.parse(url) == nil)
    }
}
