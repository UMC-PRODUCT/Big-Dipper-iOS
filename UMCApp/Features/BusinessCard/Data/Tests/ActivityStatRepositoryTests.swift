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
        func fetchMyProfile() async throws -> Profile { profile }
    }

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

        #expect(try await sut.fetchStudyCount() == 3)
    }

    @Test("스터디 카운트 — 서버가 hasNext를 문자열로 줘도 흡수한다")
    func studyCountAbsorbsStringBool() async throws {
        let stub = StubRequesting()
        stub.responsesByPath["/api/v1/study-groups/managed"] = Data("""
        {"success":true,"code":"200","message":"ok",
         "result":{"content":[{"id":"1"}],"hasNext":"true"}}
        """.utf8)
        let sut = ActivityStatRepository(
            networkRequesting: stub, memberProfileRepository: StubProfileRepository()
        )

        #expect(try await sut.fetchStudyCount() == 1)
    }

    @Test("활동 카운트 — admin 제외 챌린저 기록 수")
    func activityCountFromProfile() async throws {
        let profileStub = StubProfileRepository()
        profileStub.profile = Profile(
            memberId: "42", name: "정의찬", nickname: "제옹", generations: ["11", "12"],
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

        #expect(try await sut.fetchActivityCount() == 1)
    }
}
