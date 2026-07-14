//
//  StudyRouterMemberPointTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation
import Testing
import Moya
import Alamofire
import UMCFoundation
@testable import ActivityData

// MARK: - Helpers

private func requestParameters(
    of task: Moya.Task
) -> (parameters: [String: Any], encoding: ParameterEncoding)? {
    guard case let .requestParameters(parameters, encoding) = task else {
        return nil
    }
    return (parameters, encoding)
}

private func makePointBody() -> ChallengerPointCreateRequestDTO {
    ChallengerPointCreateRequestDTO(
        pointType: .blogChallenge,
        pointValue: 3,
        description: "블로그 챌린지 완료"
    )
}

// MARK: - Suite: 멤버/포인트 path·method 계약

@Suite("StudyRouter — 멤버/포인트 엔드포인트 매핑 (API 계약)")
struct StudyRouterMemberPointPathMethodTests {

    @Test("각 멤버/포인트 case 는 명세된 path 로 매핑된다")
    func pathMapsEachCase() {
        let search = StudyRouter.searchChallengersOffset(
            query: ChallengerSearchQuery(page: 0, size: 20, schoolId: "5")
        )
        let create = StudyRouter.createChallengerPoint(
            challengerId: "7", body: makePointBody()
        )
        let delete = StudyRouter.deleteChallengerPoint(challengerPointId: "99")
        let profile = StudyRouter.getChallengerProfile(challengerId: "7")

        #expect(search.path == "/api/v1/challenger/search/offset")
        #expect(create.path == "/api/v1/challenger/7/points")
        #expect(delete.path == "/api/v1/challenger/points/99")
        #expect(profile.path == "/api/v1/challenger/7")
    }

    @Test("searchChallengersOffset / getChallengerProfile 의 method 는 GET 이다")
    func getMethods() {
        let search = StudyRouter.searchChallengersOffset(
            query: ChallengerSearchQuery(page: 0, size: 20, schoolId: "5")
        )
        let profile = StudyRouter.getChallengerProfile(challengerId: "7")

        #expect(search.method == .get)
        #expect(profile.method == .get)
    }

    @Test("createChallengerPoint 의 method 는 POST 이다")
    func createMethodIsPost() {
        let create = StudyRouter.createChallengerPoint(
            challengerId: "7", body: makePointBody()
        )
        #expect(create.method == .post)
    }

    @Test("deleteChallengerPoint 의 method 는 DELETE 이다")
    func deleteMethodIsDelete() {
        let delete = StudyRouter.deleteChallengerPoint(challengerPointId: "99")
        #expect(delete.method == .delete)
    }
}

// MARK: - Suite: 멤버/포인트 task 형태 계약

@Suite("StudyRouter — 멤버/포인트 task 형태 계약")
struct StudyRouterMemberPointTaskTests {

    @Test("searchChallengersOffset 는 query DTO 를 queryString 으로 인코딩한다")
    func searchTaskEncodesQueryString() throws {
        let router = StudyRouter.searchChallengersOffset(
            query: ChallengerSearchQuery(page: 2, size: 20, schoolId: "5")
        )

        let extracted = try #require(requestParameters(of: router.task))

        #expect(extracted.parameters["page"] as? Int == 2)
        #expect(extracted.parameters["size"] as? Int == 20)
        #expect(extracted.parameters["schoolId"] as? String == "5")
        #expect((extracted.encoding as? URLEncoding)?.destination == .queryString)
    }

    @Test("createChallengerPoint 의 task 는 requestJSONEncodable 이다")
    func createTaskIsJSONEncodable() {
        let router = StudyRouter.createChallengerPoint(
            challengerId: "7", body: makePointBody()
        )
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }

    @Test(
        "조회/삭제 case 의 task 는 requestPlain 이다",
        arguments: [
            StudyRouter.deleteChallengerPoint(challengerPointId: "99"),
            StudyRouter.getChallengerProfile(challengerId: "7")
        ]
    )
    func plainTasks(router: StudyRouter) {
        if case .requestPlain = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestPlain 여야 함 — 실제: \(router.task)")
        }
    }
}

// MARK: - Suite: ChallengerSearchQuery / Request DTO 인코딩 계약

@Suite("ChallengerSearchQuery·ChallengerPointCreateRequestDTO — 인코딩 계약")
struct ChallengerSearchAndPointDTOEncodingTests {

    @Test("ChallengerSearchQuery — page/size 는 Int, schoolId 는 String 으로 캡슐화한다")
    func searchQueryParameters() {
        let query = ChallengerSearchQuery(page: 1, size: 20, schoolId: "5")

        let parameters = query.toParameters

        #expect(parameters.count == 3)
        #expect(parameters["page"] as? Int == 1)
        #expect(parameters["size"] as? Int == 20)
        #expect(parameters["schoolId"] as? String == "5")
        #expect(parameters["schoolId"] as? Int == nil)      // 식별자는 숫자가 아님
    }

    @Test("ChallengerPointCreateRequestDTO — pointType 은 서버 rawValue, 배점은 정수로 직렬화한다")
    func pointCreateDTOEncoding() throws {
        let dto = ChallengerPointCreateRequestDTO(
            pointType: .blogChallenge, pointValue: 3, description: "완료"
        )
        let data = try JSONEncoder().encode(dto)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(json["pointType"] as? String == "BLOG_CHALLENGE")
        #expect(json["pointValue"] as? Int == 3)
        #expect(json["description"] as? String == "완료")
        #expect(json.keys.count == 3)
    }
}
