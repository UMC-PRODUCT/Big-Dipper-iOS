//
//  ProfileToMyCardTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import UMCFoundation
import CoreDomain
import BusinessCardDomain
@testable import BusinessCardData

@Suite("Profile → MyCard 매핑 — 정본 파생 규칙(Profile+ProfileData)과 일치")
struct ProfileToMyCardTests {

    @Test("최신 기수 챌린저 기록에서 기수·파트·학교를 파생한다")
    func derivesFromLatestRecord() {
        let profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹",
            generations: ["11", "12"], schoolName: "한양대학교",
            email: "one@umc.dev",
            externalLinks: ProfileExternalLinks(
                id: "1", linkedIn: nil, instagram: nil,
                github: "github.com/UMC-PRODUCT", blog: nil, personal: nil
            ),
            challengerRecords: [
                makeRecord(gisu: "11", part: "DESIGN"),
                makeRecord(gisu: "12", part: "IOS"),
            ]
        )

        let card = profile.toMyCard()

        #expect(card.memberId == "42")
        #expect(card.generation == "12")
        #expect(card.part == .front(type: .ios))
        #expect(card.university == "한양대학교")
        #expect(card.github == "github.com/UMC-PRODUCT")
        #expect(card.email == "one@umc.dev")
    }

    @Test("챌린저 기록이 없으면 기수 0·admin 폴백으로도 명함이 만들어진다")
    func fallsBackWithoutRecords() {
        let profile = Profile(memberId: "42", name: "정의찬", nickname: "제옹", generations: [])

        let card = profile.toMyCard()

        #expect(card.generation == "0")
        #expect(card.part == .admin)
    }

    @Test("빈 이메일·공백 링크는 nil로 정리된다")
    func blankOptionalFieldsBecomeNil() {
        let profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: [],
            email: "",
            externalLinks: ProfileExternalLinks(
                id: "1", linkedIn: nil, instagram: nil, github: "  ", blog: nil, personal: nil
            )
        )

        let card = profile.toMyCard()

        #expect(card.email == nil)
        #expect(card.github == nil)
    }

    private func makeRecord(gisu: String, part: String) -> ProfileChallengerRecord {
        ProfileChallengerRecord(
            challengerId: "c\(gisu)", memberId: "42", gisu: gisu, gisuId: gisu,
            chapterId: nil, chapterName: nil, part: part,
            schoolId: "1", schoolName: "한양대학교",
            name: "정의찬", nickname: "제옹", email: nil, profileImageLink: nil,
            status: .active, challengerPoints: []
        )
    }
}
