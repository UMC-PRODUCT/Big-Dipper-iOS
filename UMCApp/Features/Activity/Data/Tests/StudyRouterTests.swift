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

// MARK: - CRUD Helpers

private func makeCreateBody() -> StudyGroupCreateRequestDTO {
    StudyGroupCreateRequestDTO(
        gisuId: 7,
        name: "iOS 스터디",
        part: "IOS",
        memberIds: [1, 2],
        mentorIds: [3]
    )
}

private func makeScheduleBody() -> StudyGroupScheduleCreateRequestDTO {
    StudyGroupScheduleCreateRequestDTO(
        scheduleId: 10,
        studyGroupId: 42,
        weeklyCurriculumId: 5
    )
}

private func encodeToJSON(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let obj = try JSONSerialization.jsonObject(with: data)
    return try #require(obj as? [String: Any])
}

// MARK: - Suite: CRUD/연결 path·method 계약

@Suite("StudyRouter — CRUD/연결 엔드포인트 매핑 (API 계약)")
struct StudyRouterCRUDPathMethodTests {

    // MARK: - Path

    @Test("각 CRUD/연결 case 는 명세된 path 로 매핑된다")
    func crudPathMapsEachCase() {
        // Given
        let create = StudyRouter.createStudyGroup(body: makeCreateBody())
        let update = StudyRouter.updateStudyGroup(
            groupId: "42", body: StudyGroupUpdateRequestDTO(name: "n")
        )
        let delete = StudyRouter.deleteStudyGroup(groupId: "42")
        let addMember = StudyRouter.addStudyGroupMember(groupId: "42", memberId: "7")
        let removeMember = StudyRouter.removeStudyGroupMember(groupId: "42", memberId: "7")
        let addMentor = StudyRouter.addStudyGroupMentor(groupId: "42", mentorId: "9")
        let removeMentor = StudyRouter.removeStudyGroupMentor(groupId: "42", mentorId: "9")
        let link = StudyRouter.linkStudyGroupSchedule(body: makeScheduleBody())

        // Then
        #expect(create.path == "/api/v1/study-groups")
        #expect(update.path == "/api/v1/study-groups/42")
        #expect(delete.path == "/api/v1/study-groups/42")
        #expect(addMember.path == "/api/v1/study-groups/42/members/7")
        #expect(removeMember.path == "/api/v1/study-groups/42/members/7")
        #expect(addMentor.path == "/api/v1/study-groups/42/mentors/9")
        #expect(removeMentor.path == "/api/v1/study-groups/42/mentors/9")
        #expect(link.path == "/api/v1/study-groups/schedules")
    }

    // MARK: - Method

    @Test(
        "POST case 의 HTTP method 는 POST 이다",
        arguments: [
            StudyRouter.createStudyGroup(body: makeCreateBody()),
            StudyRouter.linkStudyGroupSchedule(body: makeScheduleBody())
        ]
    )
    func methodIsPost(router: StudyRouter) {
        #expect(router.method == .post)
    }

    @Test(
        "PATCH case 의 HTTP method 는 PATCH 이다",
        arguments: [
            StudyRouter.updateStudyGroup(
                groupId: "42", body: StudyGroupUpdateRequestDTO(name: "n")
            ),
            StudyRouter.addStudyGroupMember(groupId: "42", memberId: "7"),
            StudyRouter.addStudyGroupMentor(groupId: "42", mentorId: "9")
        ]
    )
    func methodIsPatch(router: StudyRouter) {
        #expect(router.method == .patch)
    }

    @Test(
        "DELETE case 의 HTTP method 는 DELETE 이다",
        arguments: [
            StudyRouter.deleteStudyGroup(groupId: "42"),
            StudyRouter.removeStudyGroupMember(groupId: "42", memberId: "7"),
            StudyRouter.removeStudyGroupMentor(groupId: "42", mentorId: "9")
        ]
    )
    func methodIsDelete(router: StudyRouter) {
        #expect(router.method == .delete)
    }
}

// MARK: - Suite: CRUD/연결 task 형태 계약

@Suite("StudyRouter — CRUD/연결 task 형태 계약")
struct StudyRouterCRUDTaskTests {

    @Test("createStudyGroup 의 task 는 requestJSONEncodable 이다")
    func createStudyGroupTaskIsJSONEncodable() {
        let router = StudyRouter.createStudyGroup(body: makeCreateBody())
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }

    @Test("updateStudyGroup 의 task 는 requestJSONEncodable 이다")
    func updateStudyGroupTaskIsJSONEncodable() {
        let router = StudyRouter.updateStudyGroup(
            groupId: "42", body: StudyGroupUpdateRequestDTO(name: "n")
        )
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }

    @Test("linkStudyGroupSchedule 의 task 는 requestJSONEncodable 이다")
    func linkStudyGroupScheduleTaskIsJSONEncodable() {
        let router = StudyRouter.linkStudyGroupSchedule(body: makeScheduleBody())
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }

    @Test(
        "결과 없는 변경(delete/멤버·멘토) case 의 task 는 requestPlain 이다",
        arguments: [
            StudyRouter.deleteStudyGroup(groupId: "42"),
            StudyRouter.addStudyGroupMember(groupId: "42", memberId: "7"),
            StudyRouter.removeStudyGroupMember(groupId: "42", memberId: "7"),
            StudyRouter.addStudyGroupMentor(groupId: "42", mentorId: "9"),
            StudyRouter.removeStudyGroupMentor(groupId: "42", mentorId: "9")
        ]
    )
    func voidMutationTaskIsPlain(router: StudyRouter) {
        if case .requestPlain = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestPlain 여야 함 — 실제: \(router.task)")
        }
    }
}

// MARK: - Suite: Request DTO JSON 인코딩 계약

@Suite("StudyRouter — Request DTO JSON 인코딩 계약")
struct StudyRouterRequestDTOEncodingTests {

    @Test("StudyGroupCreateRequestDTO — 식별자를 정수/정수 배열로 직렬화한다 (문자열 아님)")
    func createDTOEncodesIdentifiersAsIntegers() throws {
        let dto = StudyGroupCreateRequestDTO(
            gisuId: 7,
            name: "iOS 스터디",
            part: "IOS",
            memberIds: [1, 2],
            mentorIds: [3]
        )
        let json = try encodeToJSON(dto)

        // 서버가 식별자를 정수로 받으므로 Int/[Int] 로 인코딩되어야 한다 (문자열 아님)
        #expect(json["gisuId"] as? Int == 7)
        #expect(json["gisuId"] as? String == nil)
        #expect(json["memberIds"] as? [Int] == [1, 2])
        #expect(json["mentorIds"] as? [Int] == [3])
        #expect(json["name"] as? String == "iOS 스터디")
        #expect(json["part"] as? String == "IOS")
        #expect(json.keys.count == 5)
    }

    @Test("StudyGroupUpdateRequestDTO — name 키만 인코딩한다")
    func updateDTOEncodesNameOnly() throws {
        let dto = StudyGroupUpdateRequestDTO(name: "새 이름")
        let json = try encodeToJSON(dto)
        #expect(json["name"] as? String == "새 이름")
        #expect(json.keys.count == 1)
    }

    @Test("StudyGroupScheduleCreateRequestDTO — 세 식별자를 정수로 직렬화한다 (문자열 아님)")
    func scheduleDTOEncodesIdentifiersAsIntegers() throws {
        let dto = StudyGroupScheduleCreateRequestDTO(
            scheduleId: 10,
            studyGroupId: 42,
            weeklyCurriculumId: 5
        )
        let json = try encodeToJSON(dto)
        #expect(json["scheduleId"] as? Int == 10)
        #expect(json["studyGroupId"] as? Int == 42)
        #expect(json["weeklyCurriculumId"] as? Int == 5)
        #expect(json["scheduleId"] as? String == nil)
        #expect(json.keys.count == 3)
    }
}
