//
//  CardLinkTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import BusinessCardDomain

/// 명함 딥링크는 **Android 와 맞춘 크로스 플랫폼 계약**이다. 두 앱이 같은 QR 을
/// 읽어야 하므로 형식이 바뀌면 여기서 먼저 깨져야 한다.
@Suite("CardLink — 명함 딥링크 생성·파싱")
struct CardLinkTests {

    /// Android `QrCodeViewModel` 이 굽는 문자열과 **문자 그대로** 같아야 한다 — 저쪽
    /// NavHost 패턴(`umc://card?memberId={memberId}`)이 이 형식만 명함 화면에 매칭한다.
    @Test("urlString은 Android와 같은 커스텀 스킴 질의형이다 — umc://card?memberId=")
    func urlStringFormat() {
        #expect(CardLink(memberId: "42").urlString == "umc://card?memberId=42")
    }

    @Test("생성한 URL을 다시 파싱하면 같은 memberId가 나온다")
    func roundtrip() throws {
        let link = CardLink(memberId: "42")

        let parsed = CardLink.parse(try #require(link.url))

        #expect(parsed?.memberId == "42")
    }

    /// 과거 정본이던 Universal Link 표기 — 이 표기로 구워진 검증기 QR 이 남아 있을 수 있다.
    @Test("과거 Universal Link 표기도 운영·dev 호스트 모두 읽는다", arguments: [
        "https://api.university.neordinary.com/mypage/card?memberId=42",
        "https://dev.api.university.neordinary.com/mypage/card?memberId=42",
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

    @Test("경로형 커스텀 스킴 umc://card/{id}도 계속 읽는다 — 과거 우리 검증기가 굽던 형식")
    func stillReadsCustomScheme() throws {
        let url = try #require(URL(string: "umc://card/42"))

        #expect(CardLink.parse(url)?.memberId == "42")
    }

    /// Android `MainNavHost` 가 등록해 둔 https 경로다 — 저쪽 매니페스트 필터가 이
    /// 경로만 알아서, 언젠가 이 표기로 구워진 링크가 돌아다닐 수 있다.
    @Test("Android가 등록한 community/threads/card 경로도 읽는다", arguments: [
        "https://api.university.neordinary.com/community/threads/card?memberId=42",
        "https://dev.api.university.neordinary.com/community/threads/card?memberId=42",
    ])
    func readsAndroidWebPath(urlString: String) throws {
        let url = try #require(URL(string: urlString))

        #expect(CardLink.parse(url)?.memberId == "42")
    }

    @Test("호스트·경로·쿼리가 어긋나면 nil", arguments: [
        // 남의 호스트
        "https://evil.com/mypage/card?memberId=42",
        // 서버가 쓰지 않는 호스트. dev 는 `dev.api…` 로 확정됐고 `alpha.api…` 는 DNS 에
        // 존재한 적이 없다 — 이 표기의 QR 은 세상에 없으므로 받아주지 않는다.
        "https://alpha.api.university.neordinary.com/mypage/card?memberId=42",
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
        // Android 경로지만 memberId 가 없다
        "https://api.university.neordinary.com/community/threads/card",
        // 질의형인데 값이 비었다
        "umc://card?memberId=",
    ])
    func rejectsInvalid(urlString: String) throws {
        let url = try #require(URL(string: urlString))

        #expect(CardLink.parse(url) == nil)
    }
}
