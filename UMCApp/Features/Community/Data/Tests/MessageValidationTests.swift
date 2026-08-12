//
//  MessageValidationTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
import UMCFoundation

@testable import CommunityDomain

@Suite("메시지 본문 검증 — 서버 규칙 선반영")
struct MessageValidationTests {

    @Test("공백만 있는 본문은 empty 로 거부된다")
    func rejectsBlankContent() {
        #expect(throws: AppError.validation(.empty(field: "메시지"))) {
            try CommunityThreadRoomUseCase.validateText("   \n\t ")
        }
    }

    @Test("2,000 code point 를 넘으면 tooLong 으로 거부된다")
    func rejectsOverlongContent() {
        let content = String(repeating: "가", count: 2_001)

        #expect(throws: AppError.validation(.tooLong(field: "메시지", maxLength: 2_000))) {
            try CommunityThreadRoomUseCase.validateText(content)
        }
    }

    @Test("경계값 2,000 code point 는 통과한다")
    func acceptsBoundaryLength() throws {
        try CommunityThreadRoomUseCase.validateText(String(repeating: "가", count: 2_000))
    }

    @Test("이모지는 code point 단위로 센다 — 그래파임 클러스터 기준이 아니다")
    func countsCodePointsNotGraphemes() throws {
        // 가족 이모지 하나는 그래파임 1개지만 code point 7개다. 서버와 같은 기준으로 센다.
        let family = "👨‍👩‍👧‍👦"
        #expect(family.count == 1)
        #expect(family.unicodeScalars.count == 7)

        try CommunityThreadRoomUseCase.validateText(family)
    }

    @Test("그래파임 수가 상한 안이어도 code point 가 넘으면 거부된다")
    func rejectsGraphemeShortButCodePointLongContent() {
        // 그래파임 300개지만 code point 2,100개 — 그래파임으로 세면 통과해 버린다.
        let content = String(repeating: "👨‍👩‍👧‍👦", count: 300)
        #expect(content.count == 300)
        #expect(content.unicodeScalars.count == 2_100)

        #expect(throws: AppError.validation(.tooLong(field: "메시지", maxLength: 2_000))) {
            try CommunityThreadRoomUseCase.validateText(content)
        }
    }
}
