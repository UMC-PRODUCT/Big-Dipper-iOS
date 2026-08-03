//
//  StudyRouterSubmissionTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import Testing
import Moya
import Alamofire
@testable import ActivityData

@Suite("StudyRouter — 제출 현황 엔드포인트 매핑 (API 계약)")
struct StudyRouterSubmissionTests {

    // MARK: - Helpers

    private func requestParameters(
        of task: Moya.Task
    ) -> (parameters: [String: Any], encoding: ParameterEncoding)? {
        guard case let .requestParameters(parameters, encoding) = task else {
            return nil
        }
        return (parameters, encoding)
    }

    // MARK: - Path / Method

    @Test("제출 현황과 그룹 이름 목록은 명세된 path 로 매핑된다")
    func pathMapsSubmissionCases() {
        let submissions = StudyRouter.getStudyMemberSubmissions(
            query: StudyMemberSubmissionQuery(size: 20)
        )

        #expect(submissions.path == "/api/v2/curriculums/workbook-submissions")
        #expect(StudyRouter.getStudyGroupNames.path == "/api/v1/study-groups/names")
    }

    @Test(
        "제출 현황 계열 case 의 HTTP method 는 GET 이다",
        arguments: [
            StudyRouter.getStudyMemberSubmissions(
                query: StudyMemberSubmissionQuery(size: 20)
            ),
            StudyRouter.getStudyGroupNames
        ]
    )
    func methodIsGet(router: StudyRouter) {
        #expect(router.method == .get)
    }

    // MARK: - Task

    @Test("getStudyGroupNames 의 task 는 requestPlain 이다")
    func groupNamesTaskIsPlain() {
        if case .requestPlain = StudyRouter.getStudyGroupNames.task {
            // 기대하는 case
        } else {
            Issue.record(
                "task가 .requestPlain 여야 함 — 실제: \(StudyRouter.getStudyGroupNames.task)"
            )
        }
    }

    @Test("제출 현황은 주차 배열을 대괄호 없이 쿼리스트링으로 인코딩한다 (서버 List 바인딩 계약)")
    func submissionsEncodesWeekNosWithoutBrackets() throws {
        // 기본값 .brackets 이면 `weekNos[]=1` 로 나가 서버 `List<Long>` 바인딩이 통째로
        // 실패한다. enum 동치 비교 대신 실제 인코딩 결과를 검증한다.
        let router = StudyRouter.getStudyMemberSubmissions(
            query: StudyMemberSubmissionQuery(weekNos: ["1", "2"], size: 20)
        )
        let extracted = try #require(requestParameters(of: router.task))
        let baseURL = try #require(URL(string: "https://example.com/submissions"))

        // 라우터가 실제로 넘긴 파라미터를 인코딩한다. 리터럴 딕셔너리를 넣으면 라우터가
        // weekNos 전달을 멈춰도 테스트가 통과해 회귀를 놓친다.
        let request = try extracted.encoding.encode(
            URLRequest(url: baseURL),
            with: extracted.parameters
        )
        let query = try #require(request.url?.query)

        #expect(query.contains("weekNos=1"))
        #expect(query.contains("weekNos=2"))
        #expect(!query.contains("weekNos%5B%5D"))
    }

    // MARK: - StudyMemberSubmissionQuery.toParameters

    @Test("필터가 모두 있으면 파라미터에 그대로 담긴다")
    func queryIncludesAllFiltersWhenPresent() {
        let query = StudyMemberSubmissionQuery(
            studyGroupId: "3",
            weekNos: ["1", "2"],
            cursor: "11",
            size: 20
        )

        let parameters = query.toParameters

        #expect(parameters.count == 4)
        #expect(parameters["studyGroupId"] as? String == "3")
        #expect(parameters["weekNos"] as? [String] == ["1", "2"])
        #expect(parameters["cursor"] as? String == "11")
        #expect(parameters["size"] as? Int == 20)
    }

    @Test("값이 없는 필터는 키 자체를 보내지 않는다 (서버가 전부 선택 파라미터)")
    func queryOmitsAbsentFilters() {
        let query = StudyMemberSubmissionQuery(size: 20)

        let parameters = query.toParameters

        #expect(parameters.count == 1)
        #expect(parameters["size"] as? Int == 20)
        #expect(parameters["studyGroupId"] == nil)
        #expect(parameters["weekNos"] == nil)
        #expect(parameters["cursor"] == nil)
    }

    @Test(
        "빈 문자열 필터도 키를 보내지 않는다 (서버 @Positive 검증 회피)",
        arguments: [
            (String?.some(""), String?.none),
            (String?.none, String?.some(""))
        ]
    )
    func queryOmitsEmptyStringFilters(studyGroupId: String?, cursor: String?) {
        let query = StudyMemberSubmissionQuery(
            studyGroupId: studyGroupId,
            cursor: cursor,
            size: 20
        )

        let parameters = query.toParameters

        #expect(parameters["studyGroupId"] == nil)
        #expect(parameters["cursor"] == nil)
    }

    @Test("불투명 커서 토큰을 변형 없이 파라미터로 전달한다")
    func queryForwardsOpaqueCursor() {
        let query = StudyMemberSubmissionQuery(cursor: "cursor-2", size: 20)

        #expect(query.toParameters["cursor"] as? String == "cursor-2")
    }
}
