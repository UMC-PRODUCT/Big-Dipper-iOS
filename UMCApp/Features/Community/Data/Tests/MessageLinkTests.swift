//
//  MessageLinkTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
import CommunityDomain

@Suite("메시지 링크 파싱·분해")
struct MessageLinkTests {

    // MARK: - parse

    @Test("커스텀 스킴 스레드·공지 링크를 인식한다")
    func parsesCustomScheme() {
        #expect(MessageLink.parse("umc://thread/12") == .thread(id: "12"))
        #expect(MessageLink.parse("umc://notice/7") == .notice(id: "7"))
    }

    @Test("서버가 내려주는 웹 공유 링크를 스레드로 해석한다")
    func parsesWebShareLink() {
        #expect(MessageLink.parse("https://umc.it.kr/t/12") == .thread(id: "12"))
    }

    @Test("외부 URL 은 내부 링크로 인식하지 않는다")
    func rejectsExternalURL() {
        #expect(MessageLink.parse("https://umc.it.kr/docs") == nil)
        #expect(MessageLink.parse("https://google.com/t/12") == nil)
        #expect(MessageLink.parse("umc://unknown/12") == nil)
    }

    @Test("식별자가 없거나 숫자가 아니면 거부한다")
    func rejectsInvalidIdentifier() {
        #expect(MessageLink.parse("umc://thread/") == nil)
        #expect(MessageLink.parse("umc://thread/abc") == nil)
        #expect(MessageLink.parse("https://umc.it.kr/t/") == nil)
    }

    @Test("생성한 URL 을 되파싱하면 원래 링크가 나온다")
    func roundTripsURL() throws {
        let link = MessageLink.thread(id: "12")
        let url = try #require(link.url)

        #expect(url.absoluteString == "umc://thread/12")
        #expect(MessageLink.parse(url) == link)
    }

    // MARK: - segments

    @Test("본문에서 내부 링크만 골라 앞뒤 텍스트와 함께 순서대로 분해한다")
    func splitsSegments() {
        let segments = MessageLink.segments(in: "이거 봐 umc://thread/12 그리고 umc://notice/7 도")

        #expect(segments == [
            .text("이거 봐 "),
            .link(.thread(id: "12"), raw: "umc://thread/12"),
            .text(" 그리고 "),
            .link(.notice(id: "7"), raw: "umc://notice/7"),
            .text(" 도"),
        ])
    }

    @Test("외부 URL 만 있는 본문은 통째로 텍스트 한 조각이다")
    func keepsExternalURLAsText() {
        let content = "자료는 https://umc.it.kr/docs 참고"

        #expect(MessageLink.segments(in: content) == [.text(content)])
    }

    @Test("빈 본문은 조각이 없다")
    func handlesEmptyContent() {
        #expect(MessageLink.segments(in: "").isEmpty)
    }
}
