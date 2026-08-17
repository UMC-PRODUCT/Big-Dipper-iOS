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

    @Test("외부 링크 3종(github·linkedIn·blog)이 모두 명함으로 넘어온다 — 시안 뒷면 3줄")
    func mapsAllThreeExternalLinks() {
        let profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: [],
            externalLinks: ProfileExternalLinks(
                id: "1",
                linkedIn: "linkedin.com/in/umc",
                instagram: "instagram.com/umc",
                github: "github.com/UMC-PRODUCT",
                blog: "umc.tistory.com",
                personal: "umc.dev"
            )
        )

        let card = profile.toMyCard()

        #expect(card.github == "github.com/UMC-PRODUCT")
        #expect(card.linkedIn == "linkedin.com/in/umc")
        #expect(card.blog == "umc.tistory.com")
    }

    @Test("챌린저 기록이 없으면 기수 0·admin 폴백으로도 명함이 만들어진다")
    func fallsBackWithoutRecords() {
        let profile = Profile(memberId: "42", name: "정의찬", nickname: "제옹", generations: [])

        let card = profile.toMyCard()

        #expect(card.generation == "0")
        #expect(card.part == .admin)
        // 기록이 없는 것은 「파트 없음」이지 「못 읽음」이 아니다 — 원본을 남기지 않는다.
        #expect(card.partRaw == nil)
    }

    /// 서버가 파트를 추가하면 앱이 갱신되기 전까지 우리 서버 값도 못 읽는 문자열이 된다.
    /// 그때 `.admin` 으로 눌러 버리면 자기 명함이 「운영진」이 되고, 그 값이 교환
    /// 페이로드에 실려 상대에게까지 퍼진다.
    @Test("서버가 준 모르는 파트는 원본을 남기고 전송에도 원본이 실린다")
    func unrecognizedServerPartKeepsRaw() throws {
        let profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: ["12"],
            roles: [
                ProfileRole(
                    id: "1", challengerId: "100", gisu: "12", gisuId: "10",
                    roleType: .schoolPresident, organizationType: .school,
                    organizationId: "3", responsiblePart: "RUST"
                )
            ]
        )

        let card = profile.toMyCard()

        #expect(card.part == .admin)
        #expect(card.partRaw == "RUST")
        #expect(card.partDisplayName == "RUST")
        #expect(try card.toExchangePayload().part == "RUST")
    }

    @Test("빈 이메일·공백 링크는 nil로 정리된다")
    func blankOptionalFieldsBecomeNil() {
        let profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: [],
            email: "",
            externalLinks: ProfileExternalLinks(
                id: "1", linkedIn: "  ", instagram: nil, github: "  ", blog: nil, personal: nil
            )
        )

        let card = profile.toMyCard()

        #expect(card.email == nil)
        #expect(card.github == nil)
        #expect(card.linkedIn == nil)
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
