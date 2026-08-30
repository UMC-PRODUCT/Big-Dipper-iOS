//
//  MemberStatsRepositoryTests.swift
//  BusinessCardDataTests
//
//  Created by JEONG on 8/30/26.
//

import Foundation
import Testing
import Moya
import CoreDomain
import CoreNetwork
@testable import BusinessCardData

/// 서버에 `/api/v2/member/me/stats` 가 아직 없다(2026-08-30). 배포되는 날 갈아 끼울
/// 구현이라, 계약이 맞는지는 여기서만 확인된다.
@Suite("MemberStatsRepository — 통합 카운트 한 방 조회")
struct MemberStatsRepositoryTests {

    private final class StubRequesting: BusinessCardNetworkRequesting, @unchecked Sendable {
        var data = Data()
        func request<T: TargetType>(_ target: T) async throws -> Response {
            Response(statusCode: 200, data: data)
        }
    }

    private final class StubProfileRepository:
        MemberProfileRepositoryProtocol, @unchecked Sendable {
        func fetchMyProfile() async throws -> Profile {
            Profile(memberId: "42", name: "정의찬", nickname: "제옹", generations: [])
        }
    }

    @Test("APIResponse 봉투를 벗기고 scrapCount를 스크랩 자리에 싣는다")
    func decodesWrappedStats() async throws {
        let stub = StubRequesting()
        stub.data = Data("""
        {"success":true,"code":"200","message":"ok",
         "result":{"receivedCardCount":"12","studyCount":"3","scrapCount":"7"}}
        """.utf8)
        let sut = MemberStatsRepository(
            networkRequesting: stub, memberProfileRepository: StubProfileRepository()
        )

        let stats = try await sut.fetchMemberStats()

        #expect(stats.receivedCardCount == "12")
        #expect(stats.studyCount == "3")
        #expect(stats.bookmarkCount == "7")
    }

    /// 못 읽었는데 0을 돌려주면 UseCase가 「0개」와 구분할 수 없다 (#1222).
    @Test("응답을 못 읽으면 0이 아니라 에러를 던진다")
    func throwsOnUndecodableResponse() async throws {
        let sut = MemberStatsRepository(
            networkRequesting: StubRequesting(),
            memberProfileRepository: StubProfileRepository()
        )

        await #expect(throws: (any Error).self) {
            _ = try await sut.fetchMemberStats()
        }
    }
}
