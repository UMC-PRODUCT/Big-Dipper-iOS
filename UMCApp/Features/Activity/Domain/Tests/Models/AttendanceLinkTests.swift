//
//  AttendanceLinkTests.swift
//  ActivityDomainTests
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("AttendanceLink — 출석 딥링크 표기")
struct AttendanceLinkTests {

    /// 서버가 굽는 문자열과 앱이 읽는 문자열이 같은 표를 봐야 푸시 탭이 세션에 착지한다.
    @Test("구운 링크를 그대로 다시 읽는다")
    func roundTripsCanonicalString() throws {
        let link = AttendanceLink(scheduleId: "1234")

        #expect(link.urlString == "umc://attendance/1234")
        #expect(AttendanceLink.parse(try #require(link.url)) == link)
    }

    /// 서버 식별자는 정수의 String 직렬화라, 숫자가 아닌 값은 출석 링크가 아니다.
    @Test("숫자가 아닌 식별자는 거부한다", arguments: [
        "umc://attendance/abc",
        "umc://attendance/12a",
        "umc://attendance/",
    ])
    func rejectsNonNumericIdentifier(_ raw: String) {
        #expect(AttendanceLink.parse(URL(string: raw)!) == nil)
    }

    /// 같은 스킴을 쓰는 다른 표기를 물면 스레드·명함 링크가 출석으로 새어 나간다.
    @Test("다른 host 의 내부 링크는 물지 않는다", arguments: [
        "umc://thread/1",
        "umc://card?memberId=1",
        "https://umc.it.kr/t/1",
    ])
    func rejectsOtherLinks(_ raw: String) {
        #expect(AttendanceLink.parse(URL(string: raw)!) == nil)
    }
}
