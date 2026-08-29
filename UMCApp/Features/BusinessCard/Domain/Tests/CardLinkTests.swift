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

    // MARK: - Expiry (#1226)

    /// Android 는 패턴에 선언된 질의만 읽고 나머지를 버리므로 `exp` 를 붙여도 저쪽이 안 깨진다.
    /// 그 전제가 성립하려면 **memberId 앞부분이 그대로 남아 있어야** 한다.
    @Test("만료가 있으면 기존 형식 뒤에 exp를 덧붙인다")
    func urlStringAppendsExpiry() {
        let link = CardLink(memberId: "42", expiresAt: Date(timeIntervalSince1970: 1_800))

        #expect(link.urlString == "umc://card?memberId=42&exp=1800")
    }

    @Test("만료가 없으면 형식이 그대로다 — Android 가 굽는 값과 문자 그대로 같다")
    func urlStringOmitsMissingExpiry() {
        #expect(CardLink(memberId: "42").urlString == "umc://card?memberId=42")
    }

    @Test("굽고 다시 읽으면 만료 시각이 초 단위로 살아 돌아온다")
    func expiryRoundtrip() throws {
        let issued = CardLink.issued(memberId: "42", now: Date(timeIntervalSince1970: 1_000))

        let url = try #require(issued.url)
        let parsed = try #require(CardLink.parse(url))

        #expect(parsed.memberId == "42")
        #expect(parsed.expiresAt == issued.expiresAt)
    }

    @Test("발급한 링크는 지금 유효하고 유효기간이 지나면 만료된다")
    func issuedLinkExpiresAfterValidity() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let link = CardLink.issued(memberId: "42", now: now)
        let expiresAt = try #require(link.expiresAt)

        #expect(link.isExpired(now: now) == false)
        #expect(link.isExpired(now: expiresAt.addingTimeInterval(-1)) == false)
        #expect(link.isExpired(now: expiresAt.addingTimeInterval(1)))
    }

    /// `exp` 도입 전에 구워진 QR 과 Android 가 굽는 링크에는 만료가 없다. 이걸 「지금 만료」로
    /// 읽으면 정상 명함 수신이 통째로 죽는다.
    @Test("만료가 없는 링크는 언제 읽어도 만료가 아니다")
    func linkWithoutExpiryNeverExpires() throws {
        let url = try #require(URL(string: "umc://card?memberId=42"))
        let parsed = try #require(CardLink.parse(url))

        #expect(parsed.expiresAt == nil)
        #expect(parsed.isExpired(now: .distantFuture) == false)
    }

    /// 못 읽은 값을 「만료」로 처리하면 오타 하나가 멀쩡한 명함을 막는다.
    @Test("exp가 숫자가 아니면 만료 없음으로 읽는다", arguments: [
        "umc://card?memberId=42&exp=soon",
        "umc://card?memberId=42&exp=",
    ])
    func malformedExpiryIsIgnored(urlString: String) throws {
        let url = try #require(URL(string: urlString))
        let parsed = try #require(CardLink.parse(url))

        #expect(parsed.memberId == "42")
        #expect(parsed.expiresAt == nil)
    }

    /// 만료된 링크도 **구조적으로는** 읽혀야 한다. 파싱이 거부하면 명함첩에 저장된
    /// `cardLink` 에서 memberId 를 되읽는 경로가 시간이 지났다고 깨지고, 수신 화면이
    /// 「만료됐다」고 안내할 근거조차 사라진다.
    @Test("만료된 링크도 파싱은 성공한다 — 거부는 수신 시점의 몫")
    func expiredLinkStillParses() throws {
        let expired = CardLink(memberId: "42", expiresAt: Date(timeIntervalSince1970: 1))

        let url = try #require(expired.url)
        let parsed = try #require(CardLink.parse(url))

        #expect(parsed.memberId == "42")
        #expect(parsed.isExpired())
    }

    // MARK: - Legacy Sunset (#1226)

    /// 폐기 형식(구 Universal Link 2종 · 경로형 커스텀 스킴)의 수용 종료 기한.
    ///
    /// 기한을 주석에만 적으면 아무도 안 본다. 이 테스트가 그날 **CI 를 먼저 세운다** —
    /// 그때 폐기 경로(`parseUniversalLink` · 경로형 분기)와 이 테스트를 함께 지우거나,
    /// 팀이 기한을 다시 합의해 `Constants.legacySunset` 을 미룬다.
    @Test("폐기 형식 수용 기한이 지나면 실패한다 — 그때 폐기 경로를 지운다")
    func legacyFormatsAreStillWithinSunset() {
        let sunset = CardLink.legacyFormatSunset

        #expect(
            Date() < sunset,
            "폐기 형식 수용 기한(\(sunset)) 초과. CardLink 의 폐기 파싱 경로를 지우거나 기한 재합의."
        )
    }
}
