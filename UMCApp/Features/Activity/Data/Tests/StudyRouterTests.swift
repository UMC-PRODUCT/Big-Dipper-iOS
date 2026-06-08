//
//  StudyRouterTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Testing
import Moya
import Alamofire
@testable import ActivityData

@Suite("StudyRouter — 조회 엔드포인트 매핑 (API 계약)")
struct StudyRouterTests {

    // MARK: - Helpers

    private func requestParameters(
        of task: Moya.Task
    ) -> (parameters: [String: Any], encoding: ParameterEncoding)? {
        guard case let .requestParameters(parameters, encoding) = task else {
            return nil
        }
        return (parameters, encoding)
    }

    // MARK: - Path

    @Test("각 case 는 명세된 path 로 매핑된다")
    func pathMapsEachCase() {
        // Given
        let curriculum = StudyRouter.getCurriculum(
            query: CurriculumOverviewQuery(gisuId: "7", part: "BE", weekNo: 3)
        )
        let managed = StudyRouter.getMyStudyGroups(
            query: MyStudyGroupsQuery(cursor: nil, size: 20)
        )
        let detail = StudyRouter.getStudyGroupDetail(groupId: "42")
        let profile = StudyRouter.getMemberProfile(memberId: "99")

        // Then
        #expect(curriculum.path == "/api/v2/curriculums/overview")
        #expect(managed.path == "/api/v1/study-groups/managed")
        #expect(detail.path == "/api/v1/study-groups/42")
        #expect(profile.path == "/api/v1/member/profile/99")
    }

    // MARK: - Method

    @Test("모든 조회 case 의 HTTP method 는 GET 이다")
    func methodIsGetForAllCases() {
        // Given
        let routers: [StudyRouter] = [
            .getCurriculum(
                query: CurriculumOverviewQuery(gisuId: "7", part: "BE", weekNo: nil)
            ),
            .getMyStudyGroups(query: MyStudyGroupsQuery(cursor: 10, size: 20)),
            .getStudyGroupDetail(groupId: "42"),
            .getMemberProfile(memberId: "99")
        ]

        // Then
        for router in routers {
            #expect(router.method == .get)
        }
    }

    // MARK: - Task

    @Test("getCurriculum 은 query DTO 를 queryString 으로 인코딩한다")
    func getCurriculumTaskEncodesQueryString() throws {
        // Given
        let router = StudyRouter.getCurriculum(
            query: CurriculumOverviewQuery(gisuId: "7", part: "BE", weekNo: 3)
        )

        // When
        let extracted = try #require(requestParameters(of: router.task))

        // Then
        #expect(extracted.parameters["gisuId"] as? String == "7")
        #expect(extracted.parameters["part"] as? String == "BE")
        #expect(extracted.parameters["weekNo"] as? Int == 3)
        #expect((extracted.encoding as? URLEncoding)?.destination == .queryString)
    }

    @Test("getMyStudyGroups 는 query DTO 를 queryString 으로 인코딩한다")
    func getMyStudyGroupsTaskEncodesQueryString() throws {
        // Given
        let router = StudyRouter.getMyStudyGroups(
            query: MyStudyGroupsQuery(cursor: 10, size: 20)
        )

        // When
        let extracted = try #require(requestParameters(of: router.task))

        // Then
        #expect(extracted.parameters["size"] as? Int == 20)
        #expect(extracted.parameters["cursor"] as? Int == 10)
        #expect((extracted.encoding as? URLEncoding)?.destination == .queryString)
    }

    @Test("getStudyGroupDetail 의 task 는 requestPlain 이다")
    func getStudyGroupDetailTaskIsPlain() {
        // Given
        let router = StudyRouter.getStudyGroupDetail(groupId: "42")

        // When
        let isPlain: Bool
        if case .requestPlain = router.task {
            isPlain = true
        } else {
            isPlain = false
        }

        // Then
        #expect(isPlain)
    }

    @Test("getMemberProfile 의 task 는 requestPlain 이다")
    func getMemberProfileTaskIsPlain() {
        // Given
        let router = StudyRouter.getMemberProfile(memberId: "99")

        // When
        let isPlain: Bool
        if case .requestPlain = router.task {
            isPlain = true
        } else {
            isPlain = false
        }

        // Then
        #expect(isPlain)
    }

    // MARK: - CurriculumOverviewQuery.toParameters

    @Test("CurriculumOverviewQuery 는 weekNo 가 있으면 파라미터에 포함한다")
    func curriculumQueryIncludesWeekNoWhenPresent() {
        // Given
        let query = CurriculumOverviewQuery(gisuId: "7", part: "BE", weekNo: 5)

        // When
        let parameters = query.toParameters

        // Then
        #expect(parameters.count == 3)
        #expect(parameters["weekNo"] as? Int == 5)
    }

    @Test("CurriculumOverviewQuery 는 weekNo 가 nil 이면 파라미터에서 제외한다")
    func curriculumQueryOmitsWeekNoWhenNil() {
        // Given
        let query = CurriculumOverviewQuery(gisuId: "7", part: "BE", weekNo: nil)

        // When
        let parameters = query.toParameters

        // Then
        #expect(parameters.count == 2)
        #expect(parameters["weekNo"] == nil)
        #expect(parameters["gisuId"] as? String == "7")
    }

    // MARK: - MyStudyGroupsQuery.toParameters

    @Test("MyStudyGroupsQuery 는 cursor 가 있으면 파라미터에 포함한다")
    func myStudyGroupsQueryIncludesCursorWhenPresent() {
        // Given
        let query = MyStudyGroupsQuery(cursor: 15, size: 20)

        // When
        let parameters = query.toParameters

        // Then
        #expect(parameters.count == 2)
        #expect(parameters["cursor"] as? Int == 15)
        #expect(parameters["size"] as? Int == 20)
    }

    @Test("MyStudyGroupsQuery 는 cursor 가 nil 이면 파라미터에서 제외한다")
    func myStudyGroupsQueryOmitsCursorWhenNil() {
        // Given
        let query = MyStudyGroupsQuery(cursor: nil, size: 20)

        // When
        let parameters = query.toParameters

        // Then
        #expect(parameters.count == 1)
        #expect(parameters["cursor"] == nil)
        #expect(parameters["size"] as? Int == 20)
    }
}
