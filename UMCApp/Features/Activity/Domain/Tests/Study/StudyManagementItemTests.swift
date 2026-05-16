//
//  StudyManagementItemTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("StudyManagementItem — 제출 상태 (도메인 규칙)")
struct StudyManagementItemTests {

    // MARK: - StudySubmitState contract

    @Test("StudySubmitState.examine 의 rawValue 는 서버 contract 인 '검토' 이다")
    func examineRawValueMatchesServerContract() {
        #expect(StudySubmitState.examine.rawValue == "검토")
    }

    // MARK: - default state

    @Test("state 를 생략하고 생성하면 .examine 이 기본값으로 적용된다")
    func defaultStateIsExamine() {
        let item = StudyManagementItem(
            name: "홍길동",
            school: "한성대",
            part: "iOS",
            title: "1주차 워크북"
        )

        #expect(item.state == .examine)
    }
}
