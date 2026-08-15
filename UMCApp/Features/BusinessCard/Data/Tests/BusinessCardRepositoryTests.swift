//
//  BusinessCardRepositoryTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import CoreDomain
import BusinessCardDomain
@testable import BusinessCardData

@Suite("BusinessCardRepository — 정본 프로필 위임")
struct BusinessCardRepositoryTests {

    @Test("forceRefresh를 정본 저장소에 그대로 전달하고 매핑 결과를 돌려준다")
    func delegatesForceRefresh() async throws {
        let stub = StubMemberProfileRepository(
            profile: Profile(memberId: "42", name: "정의찬", nickname: "제옹", generations: [])
        )
        let sut = BusinessCardRepository(memberProfileRepository: stub)

        let card = try await sut.fetchMyCard(forceRefresh: true)

        #expect(stub.lastForceRefresh == true)
        #expect(card.memberId == "42")
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
