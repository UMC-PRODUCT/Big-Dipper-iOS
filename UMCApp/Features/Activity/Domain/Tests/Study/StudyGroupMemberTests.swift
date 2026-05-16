//
//  StudyGroupMemberTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("StudyGroupMember — displayName 분기 (도메인 규칙)")
struct StudyGroupMemberTests {

    @Test("nickname 이 있으면 displayName 은 '닉네임/이름' 포맷이다")
    func displayNameWithNickname() {
        // Given
        let member = StudyGroupMember(
            serverID: "m_1",
            name: "홍길동",
            nickname: "길동이",
            university: "한성대"
        )

        // When
        let display = member.displayName

        // Then
        #expect(display == "길동이/홍길동")
    }

    @Test("nickname 이 nil 이면 displayName 은 이름만 노출한다")
    func displayNameWithoutNickname() {
        // Given
        let member = StudyGroupMember(
            serverID: "m_1",
            name: "홍길동",
            nickname: nil,
            university: "한성대"
        )

        // When
        let display = member.displayName

        // Then
        #expect(display == "홍길동")
    }
}
