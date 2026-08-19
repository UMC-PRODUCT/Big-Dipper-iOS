//
//  AppDeepLinkTests.swift
//  UMCAppTests
//

import Foundation
import Testing
import CommunityDomain
@testable import UMCApp

@Suite("AppDeepLink — 외부 링크 해석")
struct AppDeepLinkTests {

    // MARK: - Card

    /// QR 이 굽는 정본 표기. 이 해석이 없으면 스캔이 아무 일도 하지 않는다.
    @Test(
        "명함 Universal Link 를 명함 링크로 읽는다",
        arguments: [
            "https://api.university.neordinary.com/mypage/card?memberId=42",
            "https://dev.api.university.neordinary.com/mypage/card?memberId=42",
        ]
    )
    func parsesCardUniversalLink(_ raw: String) {
        #expect(AppDeepLink.parse(URL(string: raw)!) == .card(memberId: "42"))
    }

    /// Android 가 먼저 검증한 표기라 예전 QR 이 돌아다닐 수 있다.
    @Test("커스텀 스킴 명함 링크도 읽는다")
    func parsesCardCustomScheme() {
        let url = URL(string: "umc://card/42")!

        #expect(AppDeepLink.parse(url) == .card(memberId: "42"))
    }

    // MARK: - Message

    /// 명함 해석을 끼워 넣으면서 기존 경로가 밀리지 않았는지 고정한다.
    @Test("스레드 링크는 그대로 메시지 링크로 읽는다")
    func parsesThreadLink() {
        let url = URL(string: "umc://thread/12")!

        #expect(AppDeepLink.parse(url) == .message(.thread(id: "12")))
    }

    @Test("공지 링크도 메시지 링크로 읽는다")
    func parsesNoticeLink() {
        let url = URL(string: "umc://notice/34")!

        #expect(AppDeepLink.parse(url) == .message(.notice(id: "34")))
    }

    // MARK: - Foreign

    /// 소셜 로그인 콜백이 이 경로로 온다. 여기서 물면 로그인이 깨진다.
    @Test(
        "내부 링크가 아니면 nil 이라 다른 핸들러가 가져간다",
        arguments: [
            "kakao12345://oauth",
            "https://example.com/mypage/card?memberId=42",
            "https://api.university.neordinary.com/mypage/card",
            "umc://card/",
        ]
    )
    func rejectsForeignURL(_ raw: String) {
        #expect(AppDeepLink.parse(URL(string: raw)!) == nil)
    }
}
