//
//  AppDeepLinkTests.swift
//  UMCAppTests
//

import Foundation
import Testing
import ActivityDomain
import BusinessCardDomain
import CommunityDomain
@testable import UMCApp

@Suite("AppDeepLink — 외부 링크 해석")
struct AppDeepLinkTests {

    // MARK: - Card

    /// QR 이 굽는 정본 표기 — Android 와 같은 값이다. 이 해석이 없으면 스캔이 아무 일도
    /// 하지 않는다.
    @Test("정본 커스텀 스킴 명함 링크를 읽는다")
    func parsesCardCanonicalScheme() {
        let url = URL(string: "umc://card?memberId=42")!

        #expect(AppDeepLink.parse(url) == .card(CardLink(memberId: "42")))
    }

    /// 과거 정본이던 Universal Link 표기 — 이 표기로 구워진 검증기 QR 이 남아 있을 수 있다.
    @Test(
        "과거 Universal Link 표기도 명함 링크로 읽는다",
        arguments: [
            "https://api.university.neordinary.com/mypage/card?memberId=42",
            "https://dev.api.university.neordinary.com/mypage/card?memberId=42",
        ]
    )
    func parsesCardUniversalLink(_ raw: String) {
        #expect(AppDeepLink.parse(URL(string: raw)!) == .card(CardLink(memberId: "42")))
    }

    @Test("경로형 커스텀 스킴도 읽는다")
    func parsesCardCustomScheme() {
        let url = URL(string: "umc://card/42")!

        #expect(AppDeepLink.parse(url) == .card(CardLink(memberId: "42")))
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

    // MARK: - Attendance

    /// 출석 승인/반려 푸시가 싣고 오는 표기. 여기서 못 읽으면 알림을 탭해도 아무 일이 없다.
    @Test("출석 링크를 읽는다")
    func parsesAttendanceLink() {
        let url = URL(string: "umc://attendance/1234")!

        #expect(AppDeepLink.parse(url) == .attendance(AttendanceLink(scheduleId: "1234")))
    }

    /// 일정 식별자는 정수의 String 직렬화라, 숫자가 아니면 출석 링크로 열지 않는다.
    @Test(
        "숫자가 아닌 출석 링크는 열지 않는다",
        arguments: [
            "umc://attendance/abc",
            "umc://attendance/",
        ]
    )
    func rejectsMalformedAttendanceLink(_ raw: String) {
        #expect(AppDeepLink.parse(URL(string: raw)!) == nil)
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
