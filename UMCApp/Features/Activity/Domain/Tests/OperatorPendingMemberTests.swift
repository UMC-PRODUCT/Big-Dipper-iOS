//
//  OperatorPendingMemberTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/8/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("OperatorPendingMember — computed property + 매퍼 (도메인 규칙)")
struct OperatorPendingMemberTests {

    // MARK: - hasReason

    @Test("reason 이 nil 이면 hasReason=false")
    func hasReasonNilReturnsFalse() {
        let member = OperatorPendingMember(
            name: "홍길동",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0),
            reason: nil
        )

        #expect(member.hasReason == false)
    }

    @Test("reason 이 빈 문자열이면 hasReason=false (공백 포함 안된 케이스)")
    func hasReasonEmptyStringReturnsFalse() {
        let member = OperatorPendingMember(
            name: "홍길동",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0),
            reason: ""
        )

        #expect(member.hasReason == false)
    }

    @Test("reason 에 내용이 있으면 hasReason=true")
    func hasReasonWithContentReturnsTrue() {
        let member = OperatorPendingMember(
            name: "홍길동",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0),
            reason: "교통 지연"
        )

        #expect(member.hasReason == true)
    }

    // MARK: - displayName

    @Test("nickname 이 있으면 'nickname/name' 형태로 표시된다")
    func displayNameWithNickname() {
        let member = OperatorPendingMember(
            name: "홍길동",
            nickname: "길동이",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0)
        )

        #expect(member.displayName == "길동이/홍길동")
    }

    @Test("nickname 이 nil 이면 name 만 표시된다")
    func displayNameWithoutNickname() {
        let member = OperatorPendingMember(
            name: "홍길동",
            nickname: nil,
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0)
        )

        #expect(member.displayName == "홍길동")
    }
}
