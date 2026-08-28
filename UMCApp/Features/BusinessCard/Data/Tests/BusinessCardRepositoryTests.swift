//
//  BusinessCardRepositoryTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import CoreDomain
import UMCFoundation
import BusinessCardDomain
@testable import BusinessCardData

@Suite("BusinessCardRepository — 정본 프로필 위임")
struct BusinessCardRepositoryTests {

    @Test("forceRefresh를 정본 저장소에 그대로 전달하고 매핑 결과를 돌려준다")
    func delegatesForceRefresh() async throws {
        let stub = StubMemberProfileRepository(
            profile: makeProfile(records: [makeRecord(gisu: "12", part: "IOS")])
        )
        let sut = BusinessCardRepository(memberProfileRepository: stub)

        let card = try await sut.fetchMyCard(forceRefresh: true)

        #expect(stub.lastForceRefresh == true)
        #expect(card.memberId == "42")
        #expect(card.generation == "12")
    }

    /// 내 명함 경로도 같은 변환을 탄다. 기록이 없으면 예전에는 「운영진 · 0기」 명함이
    /// 그려졌는데, 그건 내 화면에 남의 정보만큼이나 틀린 값이다 (#1223).
    @Test("정본 프로필에 기록·역할이 없으면 내 명함도 실패한다")
    func failsWhenProfileHasNoRecords() async throws {
        let stub = StubMemberProfileRepository(profile: makeProfile(records: []))
        let sut = BusinessCardRepository(memberProfileRepository: stub)

        await #expect(throws: AppError.self) {
            _ = try await sut.fetchMyCard(forceRefresh: false)
        }
    }

    // MARK: - Private Function

    private func makeProfile(records: [ProfileChallengerRecord]) -> Profile {
        Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: [],
            challengerRecords: records
        )
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

private final class StubMemberProfileRepository:
    MemberProfileRepositoryProtocol, @unchecked Sendable {
    private let profile: Profile
    private(set) var lastForceRefresh: Bool?

    init(profile: Profile) { self.profile = profile }

    func fetchMyProfile() async throws -> Profile {
        profile
    }

    func fetchMyProfile(forceRefresh: Bool) async throws -> Profile {
        lastForceRefresh = forceRefresh
        return profile
    }
}
