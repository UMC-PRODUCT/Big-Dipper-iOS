//
//  ActivityStatRepositoryTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import Moya
import CoreDomain
import CoreNetwork
import UMCFoundation
@testable import BusinessCardData

@Suite("ActivityStatRepository — 카운트 디코딩")
struct ActivityStatRepositoryTests {

    private final class StubRequesting: BusinessCardNetworkRequesting, @unchecked Sendable {
        var responsesByPath: [String: Data] = [:]
        func request<T: TargetType>(_ target: T) async throws -> Response {
            Response(statusCode: 200, data: responsesByPath[target.path] ?? Data())
        }
    }

    private final class StubProfileRepository:
        MemberProfileRepositoryProtocol, @unchecked Sendable {
        var profile: Profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: []
        )
        var error: Error?
        func fetchMyProfile() async throws -> Profile {
            if let error { throw error }
            return profile
        }
    }

    private enum StubError: Error { case offline }

    @Test("스크랩 카운트 — APIResponse 래핑 응답의 totalElements를 String 그대로 통과시킨다")
    func bookmarkCountFromWrappedResponse() async throws {
        let stub = StubRequesting()
        stub.responsesByPath["/api/v1/posts/scrapped"] = Data("""
        {"success":true,"code":"200","message":"ok",
         "result":{"content":[],"page":"0","size":"1",
                   "totalElements":"7","totalPages":"7","hasNext":true,"hasPrevious":false}}
        """.utf8)
        let sut = ActivityStatRepository(
            networkRequesting: stub, memberProfileRepository: StubProfileRepository()
        )

        #expect(try await sut.fetchBookmarkCount() == "7")
    }

    @Test("스터디 카운트 — 커서 응답(총개수 없음)은 항목 수를 센다")
    func studyCountFromCursorPage() async throws {
        let stub = StubRequesting()
        stub.responsesByPath["/api/v1/study-groups/managed"] = Data("""
        {"success":true,"code":"200","message":"ok",
         "result":{"studyGroups":[{"id":"1"},{"id":"2"},{"id":"3"}],
                   "nextCursor":null,"hasNext":false}}
        """.utf8)
        let sut = ActivityStatRepository(
            networkRequesting: stub, memberProfileRepository: StubProfileRepository()
        )

        #expect(try await sut.fetchStudyCount() == "3")
    }

    /// 커서 응답엔 총개수가 없어 한 페이지만 센다. `hasNext` 가 참인데 그냥 숫자를 보여
    /// 주면 51번째부터는 없는 것처럼 보인다 — 잘렸다는 사실을 `+` 로 드러낸다 (#1222).
    @Test("스터디 카운트 — 다음 페이지가 있으면 잘림을 「+」로 표기한다 (hasNext 문자열도 흡수)")
    func studyCountMarksTruncation() async throws {
        let stub = StubRequesting()
        stub.responsesByPath["/api/v1/study-groups/managed"] = Data("""
        {"success":true,"code":"200","message":"ok",
         "result":{"content":[{"id":"1"}],"hasNext":"true"}}
        """.utf8)
        let sut = ActivityStatRepository(
            networkRequesting: stub, memberProfileRepository: StubProfileRepository()
        )

        #expect(try await sut.fetchStudyCount() == "1+")
    }

    /// 마이페이지 활동 목록과 **같은 배열**을 센다. 예전에는 여기서 `challengerRecords` 를
    /// 직접 세는 바람에 운영진 이력이 목록엔 보이고 숫자엔 빠졌다 (#1222).
    @Test("활동 카운트 — activityLogs 항목 수(운영진 역할 포함)와 일치한다")
    func activityCountMatchesActivityLogs() async throws {
        let profileStub = StubProfileRepository()
        profileStub.profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: ["11", "12"],
            roles: [
                ProfileRole(
                    id: "1", challengerId: "c12", gisu: "12", gisuId: "12",
                    roleType: .schoolPresident, organizationType: .school,
                    organizationId: "3", responsiblePart: nil
                )
            ],
            challengerRecords: [
                ProfileChallengerRecord(
                    challengerId: "c11", memberId: "42", gisu: "11", gisuId: "11",
                    chapterId: nil, chapterName: nil, part: "DESIGN",
                    schoolId: "1", schoolName: "한양대학교", name: nil, nickname: nil,
                    email: nil, profileImageLink: nil, status: .active, challengerPoints: []
                ),
                ProfileChallengerRecord(
                    challengerId: "c12", memberId: "42", gisu: "12", gisuId: "12",
                    chapterId: nil, chapterName: nil, part: "ADMIN",
                    schoolId: "1", schoolName: "한양대학교", name: nil, nickname: nil,
                    email: nil, profileImageLink: nil, status: .active, challengerPoints: []
                ),
            ]
        )
        let sut = ActivityStatRepository(
            networkRequesting: StubRequesting(), memberProfileRepository: profileStub
        )

        // 11기 디자인 챌린저 + 12기 학교 운영진 = 2건. 12기 ADMIN 기록은 역할 줄에 병합된다.
        let expected = profileStub.profile.activityLogs().count
        #expect(expected == 2)
        #expect(try await sut.fetchActivityCount() == expected)
    }

    // MARK: - 실패 경로 (#1222)

    /// 조회가 실패했는데 저장소가 0을 돌려주면 UseCase는 「0개」와 구분할 수 없다.
    /// 실패는 실패로 올려야 화면이 "-"를 그린다.
    @Test("스터디 응답을 못 읽으면 0이 아니라 에러를 던진다")
    func studyCountThrowsOnUndecodableResponse() async throws {
        let sut = ActivityStatRepository(
            networkRequesting: StubRequesting(),  // 빈 본문 — 디코딩 실패
            memberProfileRepository: StubProfileRepository()
        )

        await #expect(throws: (any Error).self) {
            _ = try await sut.fetchStudyCount()
        }
    }

    @Test("스크랩 응답을 못 읽으면 0이 아니라 에러를 던진다")
    func bookmarkCountThrowsOnUndecodableResponse() async throws {
        let sut = ActivityStatRepository(
            networkRequesting: StubRequesting(),
            memberProfileRepository: StubProfileRepository()
        )

        await #expect(throws: (any Error).self) {
            _ = try await sut.fetchBookmarkCount()
        }
    }

    // MARK: - 통합 카운트

    /// 서버에 `/me/stats` 가 배포되기 전까지 릴리스가 지나는 경로다. 세 소스 중 성공한
    /// 것만 담고 실패는 `nil` 로 남긴다 — 받은 명함 수는 이 조합이 알 수 없어 항상 `nil`.
    @Test("조합 구현의 통합 카운트는 성공한 소스만 담고 받은 명함 수는 비운다")
    func memberStatsFromCombinedSources() async throws {
        let stub = StubRequesting()
        stub.responsesByPath["/api/v1/posts/scrapped"] = Data("""
        {"success":true,"code":"200","message":"ok",
         "result":{"content":[],"page":"0","size":"1",
                   "totalElements":"7","totalPages":"7","hasNext":false,"hasPrevious":false}}
        """.utf8)
        let sut = ActivityStatRepository(
            networkRequesting: stub, memberProfileRepository: StubProfileRepository()
        )

        let stats = try await sut.fetchMemberStats()

        #expect(stats.bookmarkCount == "7")
        #expect(stats.studyCount == nil)          // 빈 본문 — 조회 실패
        #expect(stats.receivedCardCount == nil)   // 이 조합이 셀 수 없는 값
    }

    @Test("프로필 조회 실패는 활동 카운트 0이 아니라 에러로 올라온다")
    func activityCountPropagatesProfileError() async throws {
        let profileStub = StubProfileRepository()
        profileStub.error = StubError.offline
        let sut = ActivityStatRepository(
            networkRequesting: StubRequesting(), memberProfileRepository: profileStub
        )

        await #expect(throws: StubError.self) {
            _ = try await sut.fetchActivityCount()
        }
    }
}
