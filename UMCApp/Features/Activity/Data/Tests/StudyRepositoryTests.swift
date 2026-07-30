//
//  StudyRepositoryTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/24/26.
//

import Testing
import Foundation
import Moya
import ActivityDomain
import UMCFoundation
@testable import ActivityData

#if DEBUG

// MARK: - Test Double

/// ``NetworkRequesting`` 가짜 구현 (FIFO outcome 큐).
///
/// 페이지네이션처럼 호출이 여러 번 일어나는 흐름을 위해 미리 설정한 결과를 순서대로
/// 반환하고, 호출된 라우터의 경로·메서드를 기록해 엔드포인트 계약을 검증합니다.
private final class StubNetworkRequesting: NetworkRequesting, @unchecked Sendable {

    enum Outcome {
        /// 200 응답으로 주어진 JSON 본문을 반환
        case success(Data)
        /// 요청 단계에서 에러를 던짐 (비-2xx 등)
        case failure(Error)
    }

    enum StubError: Error {
        /// 준비된 outcome 보다 많은 요청이 들어왔음
        case noOutcomeQueued
    }

    private var outcomes: [Outcome]
    private(set) var requestedPaths: [String] = []
    private(set) var requestedMethods: [Moya.Method] = []
    /// 각 요청의 `cursor` 쿼리 파라미터 (없으면 `nil`). 페이지네이션 echo 검증용.
    private(set) var requestedCursors: [String?] = []

    var requestCount: Int { requestedPaths.count }
    var lastPath: String? { requestedPaths.last }
    var lastMethod: Moya.Method? { requestedMethods.last }

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func request<T: TargetType>(_ target: T) async throws -> Response {
        requestedPaths.append(target.path)
        requestedMethods.append(target.method)
        requestedCursors.append(Self.cursor(from: target.task))
        guard !outcomes.isEmpty else {
            throw StubError.noOutcomeQueued
        }
        switch outcomes.removeFirst() {
        case .success(let data):
            return Response(statusCode: 200, data: data)
        case .failure(let error):
            throw error
        }
    }

    private static func cursor(from task: Moya.Task) -> String? {
        if case let .requestParameters(parameters, _) = task {
            return parameters["cursor"] as? String
        }
        return nil
    }
}

/// ``StudyContextProviding`` 가짜 구현 — 기수·파트를 직접 지정합니다.
private struct StubStudyContext: StudyContextProviding {
    var gisuId: String?
    var part: String

    init(gisuId: String? = "7", part: String = "IOS") {
        self.gisuId = gisuId
        self.part = part
    }
}

// MARK: - Fixtures

private enum Fixture {

    /// 주차 2개(역순)로 구성된 커리큘럼. 종료일이 모두 과거라 진행률이 결정론적.
    static let curriculumObject = """
    {
      "curriculumId": "1",
      "title": "iOS 커리큘럼",
      "weeks": [
        {
          "weeklyCurriculumId": "w2", "weekNo": 2, "title": "2주차",
          "startsAt": "2000-01-08T00:00:00.000Z",
          "endsAt": "2000-01-14T00:00:00.000Z", "isExtra": false
        },
        {
          "weeklyCurriculumId": "w1", "weekNo": 1, "title": "1주차",
          "startsAt": "2000-01-01T00:00:00.000Z",
          "endsAt": "2000-01-07T00:00:00.000Z", "isExtra": false
        }
      ]
    }
    """

    /// 단일 스터디 그룹 상세 (멘토 1 + 스터디원 1)
    static let studyGroupDetailObject = """
    {
      "groupId": "42", "name": "iOS 스터디", "part": "IOS", "partDisplayName": "iOS",
      "schools": [
        {
          "schoolId": "5", "schoolName": "한성대", "logoImageId": null,
          "totalStudyGroupCount": 1, "totalMemberCount": 10
        }
      ],
      "createdAt": "2026-06-01T09:00:00.000Z", "memberCount": 2,
      "mentors": [
        {
          "challengerId": "1", "memberId": "10", "name": "멘토",
          "profileImageUrl": null, "bestWorkbookPoint": 0
        }
      ],
      "members": [
        {
          "challengerId": "2", "memberId": "20", "name": "챌린저",
          "profileImageUrl": null, "bestWorkbookPoint": 5
        }
      ]
    }
    """

    /// 필터(memberId 일치 & challengerId 비어있지 않음) 검증을 포함한 멤버 프로필
    static let memberProfileObject = """
    {
      "challengerRecords": [
        { "challengerId": "C7", "memberId": "100", "gisu": 7, "gisuId": "70" },
        { "challengerId": "C8", "memberId": "100", "gisu": 8, "gisuId": "80" },
        { "challengerId": "", "memberId": "100", "gisu": 9, "gisuId": "90" },
        { "challengerId": "CX", "memberId": "999", "gisu": 7, "gisuId": "70" }
      ]
    }
    """

    /// 적격 레코드가 없는 멤버 프로필 (memberId 불일치 / challengerId 공백)
    static let memberProfileNoEligibleObject = """
    {
      "challengerRecords": [
        { "challengerId": "", "memberId": "100", "gisu": 7, "gisuId": "70" },
        { "challengerId": "CX", "memberId": "999", "gisu": 8, "gisuId": "80" }
      ]
    }
    """

    static func success(_ resultJSON: String) -> Data {
        Data("""
        { "success": true, "code": "200", "message": "성공", "result": \(resultJSON) }
        """.utf8)
    }

    static func studyGroupsPage(
        _ detailObjects: [String],
        nextCursor: String?,
        hasNext: Bool
    ) -> String {
        let cursorField = nextCursor.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "studyGroups": [\(detailObjects.joined(separator: ","))],
          "nextCursor": \(cursorField),
          "hasNext": \(hasNext)
        }
        """
    }

    static func failureBody(code: String?, message: String?) -> Data {
        var fields: [String] = ["\"success\": false"]
        if let code { fields.append("\"code\": \"\(code)\"") }
        if let message { fields.append("\"message\": \"\(message)\"") }
        return Data("{ \(fields.joined(separator: ", ")) }".utf8)
    }
}

private typealias RepositoryPair = (StudyRepository, StubNetworkRequesting)

private func makeRepository(
    _ outcomes: [StubNetworkRequesting.Outcome],
    context: StudyContextProviding = StubStudyContext()
) -> RepositoryPair {
    let stub = StubNetworkRequesting(outcomes)
    let repository = StudyRepository(networkRequesting: stub, context: context)
    return (repository, stub)
}

private func makeRepository(
    _ outcome: StubNetworkRequesting.Outcome,
    context: StudyContextProviding = StubStudyContext()
) -> RepositoryPair {
    makeRepository([outcome], context: context)
}

// MARK: - Suite: 커리큘럼 조회 계약

@Suite("StudyRepository — 커리큘럼 조회 매핑 (도메인 규칙)")
struct StudyRepositoryCurriculumTests {

    @Test("fetchCurriculumOverview — 커리큘럼 엔드포인트를 호출하고 진행률로 매핑한다")
    func fetchCurriculumOverviewMapsProgress() async throws {
        let (sut, stub) = makeRepository(.success(Fixture.success(Fixture.curriculumObject)))

        let progress = try await sut.fetchCurriculumOverview().progress

        #expect(progress.partName == "iOS PART CURRICULUM")
        #expect(progress.totalCount == 2)
        #expect(progress.completedCount == 2)        // 모든 주차 종료 → 결정론적
        #expect(progress.curriculumTitle == "iOS 커리큘럼")
        #expect(stub.lastPath == "/api/v2/curriculums/overview")
        #expect(stub.lastMethod == .get)
    }

    @Test("fetchCurriculumOverview — 주차를 미션 카드로 매핑하고 주차 오름차순으로 정렬한다")
    func fetchCurriculumOverviewMapsAndSortsMissions() async throws {
        let (sut, _) = makeRepository(.success(Fixture.success(Fixture.curriculumObject)))

        let missions = try await sut.fetchCurriculumOverview().missions

        #expect(missions.map(\.week) == [1, 2])
        #expect(missions.allSatisfy { $0.platform == "iOS" })
    }

    /// 진행률과 미션을 각각 조회하던 구조에서는 같은 개요 엔드포인트가 2회 호출됐다.
    /// 단일 조회로 통합된 구조가 회귀하지 않도록 요청 횟수를 박제한다.
    @Test("fetchCurriculumOverview — 진행률·미션을 함께 얻어도 네트워크 요청은 1회뿐이다")
    func fetchCurriculumOverviewRequestsNetworkOnlyOnce() async throws {
        let (sut, stub) = makeRepository(.success(Fixture.success(Fixture.curriculumObject)))

        let overview = try await sut.fetchCurriculumOverview()

        #expect(stub.requestCount == 1)
        #expect(overview.progress.totalCount == 2)
        #expect(overview.missions.count == 2)
    }

    @Test("fetchCurriculumOverview — gisuId 가 없으면 네트워크 호출 없이 도메인 에러를 던진다")
    func fetchCurriculumOverviewThrowsWhenNoGeneration() async {
        let (sut, stub) = makeRepository([], context: StubStudyContext(gisuId: nil))

        await #expect(throws: DomainError.curriculumUnavailableForGeneration) {
            try await sut.fetchCurriculumOverview()
        }
        #expect(stub.requestCount == 0)
    }

    @Test("fetchWeeklyCurriculumOptions — 주차를 옵션으로 매핑하고 주차 오름차순으로 정렬한다")
    func fetchWeeklyCurriculumOptionsMapsAndSorts() async throws {
        let (sut, _) = makeRepository(.success(Fixture.success(Fixture.curriculumObject)))

        let options = try await sut.fetchWeeklyCurriculumOptions()

        #expect(options.map(\.weeklyCurriculumId) == ["w1", "w2"])
        #expect(options.map(\.weekNo) == ["1", "2"])     // 도메인 모델은 weekNo: String
    }

    @Test("fetchCurriculumOverview — isSuccess:false 면 RepositoryError.serverError 를 던진다")
    func fetchCurriculumOverviewThrowsServerError() async {
        let (sut, _) = makeRepository(
            .success(Fixture.failureBody(code: "CUR404", message: "커리큘럼 없음"))
        )

        await #expect(throws: RepositoryError.serverError(code: "CUR404", message: "커리큘럼 없음")) {
            try await sut.fetchCurriculumOverview()
        }
    }
}

// MARK: - Suite: 스터디 그룹 조회 계약

@Suite("StudyRepository — 스터디 그룹 조회 매핑 (도메인 규칙)")
struct StudyRepositoryGroupTests {

    @Test("fetchStudyGroupDetailsPage — 페이지를 매핑하고 운영 그룹 엔드포인트를 호출한다")
    func fetchStudyGroupDetailsPageMapsSuccess() async throws {
        let pageJSON = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject], nextCursor: "5", hasNext: true
        )
        let (sut, stub) = makeRepository(.success(Fixture.success(pageJSON)))

        let page = try await sut.fetchStudyGroupDetailsPage(cursor: nil, size: 20)

        #expect(page.content.count == 1)
        #expect(page.content.first?.serverID == "42")
        #expect(page.hasNext)
        #expect(page.nextCursor == "5")
        #expect(stub.lastPath == "/api/v1/study-groups/managed")
        #expect(stub.lastMethod == .get)
    }

    @Test("fetchStudyGroupDetails — 다음 페이지가 없을 때까지 누적한다")
    func fetchStudyGroupDetailsAccumulatesPages() async throws {
        let page1 = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject], nextCursor: "5", hasNext: true
        )
        let page2 = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject], nextCursor: nil, hasNext: false
        )
        let (sut, stub) = makeRepository([
            .success(Fixture.success(page1)),
            .success(Fixture.success(page2))
        ])

        let details = try await sut.fetchStudyGroupDetails()

        #expect(details.count == 2)
        #expect(stub.requestCount == 2)
    }

    @Test("fetchStudyGroupDetails — hasNext 인데 커서가 없으면 무한 루프를 막고 중단한다")
    func fetchStudyGroupDetailsStopsOnMissingCursor() async throws {
        let page = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject], nextCursor: nil, hasNext: true
        )
        let (sut, stub) = makeRepository(.success(Fixture.success(page)))

        let details = try await sut.fetchStudyGroupDetails()

        #expect(details.count == 1)
        #expect(stub.requestCount == 1)        // 두 번째 페이지를 요청하지 않음
    }

    @Test("fetchStudyGroupDetails — 불투명 nextCursor 를 다음 페이지 요청 커서로 그대로 echo 한다")
    func fetchStudyGroupDetailsEchoesOpaqueCursor() async throws {
        let page1 = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject], nextCursor: "cursor-2", hasNext: true
        )
        let page2 = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject], nextCursor: nil, hasNext: false
        )
        let (sut, stub) = makeRepository([
            .success(Fixture.success(page1)),
            .success(Fixture.success(page2))
        ])

        _ = try await sut.fetchStudyGroupDetails()

        // 1페이지는 커서 없음, 2페이지는 불투명 토큰을 숫자 변환 없이 그대로 전달.
        #expect(stub.requestedCursors == [nil, "cursor-2"])
    }

    @Test("fetchStudyGroupDetail — 단일 상세를 매핑하고 groupId 를 path 에 보간한다")
    func fetchStudyGroupDetailMapsSuccess() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(Fixture.studyGroupDetailObject))
        )

        let info = try await sut.fetchStudyGroupDetail(groupId: "42")

        #expect(info.serverID == "42")
        #expect(info.mentors.count == 1)
        #expect(info.members.count == 1)
        #expect(stub.lastPath == "/api/v1/study-groups/42")
    }
}

// MARK: - Suite: 챌린저 ID 해석 계약

@Suite("StudyRepository — 챌린저 ID 해석 (도메인 규칙)")
struct StudyRepositoryResolveChallengerTests {

    @Test(
        "resolveChallengerId — 기수/컨텍스트 폴백/첫 레코드 우선순위로 challengerId 를 해석한다",
        arguments: [
            (preferred: Optional("8"), contextGisuId: Optional("70"), expected: "C8"),
            (preferred: Optional<String>.none, contextGisuId: Optional("80"), expected: "C8"),
            (preferred: Optional<String>.none, contextGisuId: Optional("70"), expected: "C7"),
            (preferred: Optional<String>.none, contextGisuId: Optional<String>.none, expected: "C7")
        ]
    )
    func resolveChallengerIdAppliesPriority(
        preferred: String?,
        contextGisuId: String?,
        expected: String
    ) async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.memberProfileObject)),
            context: StubStudyContext(gisuId: contextGisuId)
        )

        let challengerId = try await sut.resolveChallengerId(
            memberId: "100",
            preferredGeneration: preferred
        )

        #expect(challengerId == expected)
    }

    @Test("resolveChallengerId — 적격 레코드가 없으면 nil 을 반환한다")
    func resolveChallengerIdReturnsNilWhenNoEligibleRecord() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(Fixture.memberProfileNoEligibleObject))
        )

        let challengerId = try await sut.resolveChallengerId(
            memberId: "100",
            preferredGeneration: nil
        )

        #expect(challengerId == nil)
        #expect(stub.lastPath == "/api/v1/member/profile/100")
    }
}

// MARK: - Suite: CRUD/연결 실행 계약

@Suite("StudyRepository — CRUD/연결 실행 (도메인 규칙)")
struct StudyRepositoryCRUDTests {

    /// CRUD/연결 8종. 성공/실패 검증 본문이 동일하므로 파라미터화한다
    /// (작업별로 path·method 만 다르며, 이를 케이스 메타데이터로 분리한다).
    private enum Operation: CaseIterable, CustomTestStringConvertible {
        case create, update, delete
        case addMember, removeMember, addMentor, removeMentor
        case linkSchedule

        var operationName: String {
            switch self {
            case .create: "createStudyGroup"
            case .update: "updateStudyGroup"
            case .delete: "deleteStudyGroup"
            case .addMember: "addStudyGroupMember"
            case .removeMember: "removeStudyGroupMember"
            case .addMentor: "addStudyGroupMentor"
            case .removeMentor: "removeStudyGroupMentor"
            case .linkSchedule: "linkStudyGroupSchedule"
            }
        }

        var expectedPath: String {
            switch self {
            case .create: "/api/v1/study-groups"
            case .update, .delete: "/api/v1/study-groups/1"
            case .addMember, .removeMember: "/api/v1/study-groups/1/members/2"
            case .addMentor, .removeMentor: "/api/v1/study-groups/1/mentors/2"
            case .linkSchedule: "/api/v1/study-groups/schedules"
            }
        }

        var expectedMethod: Moya.Method {
            switch self {
            case .create, .linkSchedule: .post
            case .update, .addMember, .addMentor: .patch
            case .delete, .removeMember, .removeMentor: .delete
            }
        }

        var testDescription: String { operationName }

        func invoke(on sut: StudyRepository) async throws {
            switch self {
            case .create:
                try await sut.createStudyGroup(
                    gisuId: "1", name: "n", part: .front(type: .ios),
                    memberIds: ["2"], mentorIds: ["3"]
                )
            case .update:
                try await sut.updateStudyGroup(groupId: "1", name: "n")
            case .delete:
                try await sut.deleteStudyGroup(groupId: "1")
            case .addMember:
                try await sut.addStudyGroupMember(groupId: "1", memberId: "2")
            case .removeMember:
                try await sut.removeStudyGroupMember(groupId: "1", memberId: "2")
            case .addMentor:
                try await sut.addStudyGroupMentor(groupId: "1", mentorId: "2")
            case .removeMentor:
                try await sut.removeStudyGroupMentor(groupId: "1", mentorId: "2")
            case .linkSchedule:
                try await sut.linkStudyGroupSchedule(
                    scheduleId: "1", studyGroupId: "2", weeklyCurriculumId: "3"
                )
            }
        }
    }

    @Test(
        "CRUD/연결 8종 — 성공 응답 시 명세된 path·method 로 1회 호출한다",
        arguments: Operation.allCases
    )
    private func crudSucceedsWithExpectedEndpoint(_ operation: Operation) async throws {
        let (sut, stub) = makeRepository(.success(Fixture.success("null")))

        try await operation.invoke(on: sut)

        #expect(stub.requestCount == 1)
        #expect(stub.lastPath == operation.expectedPath)
        #expect(stub.lastMethod == operation.expectedMethod)
    }

    @Test(
        "CRUD/연결 8종 — 본문 없는 2xx 응답(빈 본문)도 성공으로 처리한다",
        arguments: Operation.allCases
    )
    private func crudSucceedsOnEmptyBody(_ operation: Operation) async throws {
        // DELETE 등은 본문 없이 2xx 만 반환할 수 있다. 빈 본문을 디코딩 시도하면 실패하므로
        // 성공으로 처리해야 한다(레거시 CRUD 와 동일한 계약).
        let (sut, stub) = makeRepository(.success(Data()))

        try await operation.invoke(on: sut)

        #expect(stub.requestCount == 1)
        #expect(stub.lastPath == operation.expectedPath)
    }

    @Test(
        "CRUD/연결 8종 — 실패(success:false) 응답 시 serverError 를 던진다",
        arguments: Operation.allCases
    )
    private func crudThrowsServerErrorOnFailure(_ operation: Operation) async {
        let (sut, _) = makeRepository(
            .success(Fixture.failureBody(code: "STUDY403", message: "권한 없음"))
        )

        await #expect(
            throws: RepositoryError.serverError(code: "STUDY403", message: "권한 없음")
        ) {
            try await operation.invoke(on: sut)
        }
    }

    @Test("createStudyGroup — 식별자가 정수 문자열이 아니면 네트워크 호출 없이 던진다")
    private func createStudyGroupThrowsBeforeNetworkOnNonNumericIdentifier() async {
        // 서버는 ID 를 정수로 받으므로 Repository 가 요청을 만들 때 String→Int 로 변환한다.
        // 변환할 수 없는 값이면 요청을 보내기 전에 에러를 던진다.
        let (sut, stub) = makeRepository(.success(Fixture.success("null")))

        await #expect(throws: RepositoryError.self) {
            try await sut.createStudyGroup(
                gisuId: "abc", name: "n", part: .front(type: .ios),
                memberIds: ["2"], mentorIds: ["3"]
            )
        }
        #expect(stub.requestCount == 0)
    }
}

#endif
