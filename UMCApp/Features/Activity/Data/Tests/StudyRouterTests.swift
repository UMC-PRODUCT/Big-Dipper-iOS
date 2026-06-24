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

    @Test(
        "모든 조회 case 의 HTTP method 는 GET 이다",
        arguments: [
            StudyRouter.getCurriculum(
                query: CurriculumOverviewQuery(gisuId: "7", part: "BE", weekNo: nil)
            ),
            StudyRouter.getMyStudyGroups(query: MyStudyGroupsQuery(cursor: 10, size: 20)),
            StudyRouter.getStudyGroupDetail(groupId: "42"),
            StudyRouter.getMemberProfile(memberId: "99")
        ]
    )
    func methodIsGet(router: StudyRouter) {
        #expect(router.method == .get)
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

        // Then
        if case .requestPlain = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestPlain 여야 함 — 실제: \(router.task)")
        }
    }

    @Test("getMemberProfile 의 task 는 requestPlain 이다")
    func getMemberProfileTaskIsPlain() {
        // Given
        let router = StudyRouter.getMemberProfile(memberId: "99")

        // Then
        if case .requestPlain = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestPlain 여야 함 — 실제: \(router.task)")
        }
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

    @Test("CurriculumOverviewQuery 는 part 가 빈 문자열이어도 파라미터에 그대로 포함한다 (경계값)")
    func curriculumQueryIncludesEmptyPart() {
        // Given — part 빈 문자열 경계값. 서버 필수 필드 빈 값 허용 여부는 미확정이라
        // 추측 기반 가드(assert) 대신 현재 DTO 계약(가공 없이 그대로 전달)을 박제한다.
        let query = CurriculumOverviewQuery(gisuId: "7", part: "", weekNo: nil)

        // When
        let parameters = query.toParameters

        // Then
        #expect(parameters["part"] as? String == "")
        #expect(parameters.count == 2)
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

    @Test("MyStudyGroupsQuery 는 size 가 0 이어도 파라미터에 그대로 포함한다 (경계값)")
    func myStudyGroupsQueryIncludesZeroSize() {
        // Given — size: 0 경계값. 서버 size=0 허용 여부가 미확정이라 DTO 레벨
        // precondition 등 추측 기반 변경 대신 현재 계약(그대로 전달)을 박제한다.
        // (#814 Repository 이식 전 서버 계약 확인 시 본 테스트를 근거로 정책 결정)
        let query = MyStudyGroupsQuery(cursor: nil, size: 0)

        // When
        let parameters = query.toParameters

        // Then
        #expect(parameters["size"] as? Int == 0)
        #expect(parameters.count == 1)
    }
}
