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

/// ``NetworkRequesting`` 가짜 구현 (FIFO outcome 큐 + 멤버 프로필 경로 분리).
///
/// 페이지네이션처럼 호출이 여러 번 일어나는 흐름을 위해 미리 설정한 결과를 순서대로
/// 반환하고, 호출된 라우터의 경로·메서드를 기록해 엔드포인트 계약을 검증합니다.
///
/// 스터디 그룹 조회는 멤버마다 프로필 보강 요청을 **병렬로** 보내므로 완료 순서가
/// 비결정적입니다. 그래서 (1) 기록을 락으로 보호하고, (2) 멤버 프로필 요청은
/// ``memberProfileResponder`` 로 경로 분리해 주 엔드포인트의 FIFO 계약이 흔들리지 않게 합니다.
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

    /// 한 번의 요청 기록.
    struct Record {
        let path: String
        let method: Moya.Method
        /// `cursor` 쿼리 파라미터 (없으면 `nil`). 페이지네이션 echo 검증용.
        let cursor: String?
    }

    /// 멤버 프로필 보강 요청 경로 접두사.
    static let memberProfilePathPrefix = "/api/v1/member/profile/"

    private let lock = NSLock()
    private var outcomes: [Outcome]
    private var records: [Record] = []

    /// 멤버 프로필 요청에 `memberId` 별 응답을 돌려주는 클로저.
    ///
    /// 지정하면 FIFO 큐를 소비하지 않고 이 클로저 결과를 반환합니다. `nil` 로 두면 기존처럼
    /// FIFO 큐를 사용합니다(단일 호출인 챌린저 ID 해석 테스트).
    var memberProfileResponder: (@Sendable (String) -> Outcome)?

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    // MARK: - 기록 조회

    /// 멤버 프로필 보강을 포함한 전체 요청 기록.
    var allRecords: [Record] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    var requestedPaths: [String] { allRecords.map(\.path) }
    var requestCount: Int { allRecords.count }
    var lastPath: String? { allRecords.last?.path }
    var lastMethod: Moya.Method? { allRecords.last?.method }

    /// 멤버 프로필 보강을 **제외한** 요청 기록 — 주 엔드포인트 계약 검증용.
    private var primaryRecords: [Record] {
        allRecords.filter { !$0.path.hasPrefix(Self.memberProfilePathPrefix) }
    }

    var primaryPaths: [String] { primaryRecords.map(\.path) }
    var primaryRequestCount: Int { primaryRecords.count }
    var lastPrimaryPath: String? { primaryRecords.last?.path }
    var lastPrimaryMethod: Moya.Method? { primaryRecords.last?.method }
    var primaryCursors: [String?] { primaryRecords.map(\.cursor) }

    /// 멤버 프로필 보강 요청만 추린 경로 (병렬이라 순서는 비결정적 — 집합/개수로만 검증할 것).
    var memberProfilePaths: [String] {
        allRecords.map(\.path).filter { $0.hasPrefix(Self.memberProfilePathPrefix) }
    }

    // MARK: - NetworkRequesting

    func request<T: TargetType>(_ target: T) async throws -> Response {
        switch try nextOutcome(for: target) {
        case .success(let data):
            return Response(statusCode: 200, data: data)
        case .failure(let error):
            throw error
        }
    }

    private func nextOutcome<T: TargetType>(for target: T) throws -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        records.append(
            Record(
                path: target.path,
                method: target.method,
                cursor: Self.cursor(from: target.task)
            )
        )

        if target.path.hasPrefix(Self.memberProfilePathPrefix),
           let responder = memberProfileResponder {
            let memberID = String(target.path.dropFirst(Self.memberProfilePathPrefix.count))
            return responder(memberID)
        }

        guard !outcomes.isEmpty else {
            throw StubError.noOutcomeQueued
        }
        return outcomes.removeFirst()
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

    /// 단일 스터디 그룹 상세 (멘토 1 + 스터디원 1). 서버 `StudyGroupResponse` 실제 키 사용.
    static let studyGroupDetailObject = """
    {
      "studyGroupId": "42", "name": "iOS 스터디", "gisuId": 7, "studyPart": "IOS",
      "createdAt": "2026-06-01T09:00:00.000Z",
      "mentors": [
        {
          "memberId": "10", "memberName": "멘토", "schoolId": 5,
          "schoolName": "한성대", "profileImageUrl": null
        }
      ],
      "members": [
        {
          "memberId": "20", "memberName": "챌린저", "schoolId": 5,
          "schoolName": "한성대", "profileImageUrl": null
        }
      ]
    }
    """

    /// 보강용 멤버 프로필 — 주어진 `memberID` 에 대응하는 챌린저 레코드 1건과 닉네임을 담는다.
    static func memberProfile(
        memberID: String,
        challengerID: String,
        nickname: String?
    ) -> String {
        let nicknameField = nickname.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "nickname": \(nicknameField),
          "challengerRecords": [
            {
              "challengerId": "\(challengerID)", "memberId": "\(memberID)",
              "gisu": 7, "gisuId": "70"
            }
          ]
        }
        """
    }

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

    /// 비-2xx 실패 응답 본문 — 서버 `ApiErrorResponseFactory` 의 실제 모양.
    ///
    /// 서버는 `result` 에 객체가 아니라 **예외 메시지 문자열**을 담는다. 이 모양을 그대로
    /// 재현해 두어야, 본문을 `APIResponse<EmptyResult>` 로 디코딩하는 파싱이 그 문자열에서
    /// 실패해 코드를 놓치는 회귀를 잡을 수 있다.
    static func errorBody(code: String?, message: String) -> Data {
        var fields: [String] = ["\"success\": false"]
        if let code { fields.append("\"code\": \"\(code)\"") }
        fields.append("\"message\": \"\(message)\"")
        fields.append("\"result\": \"\(message)\"")
        return Data("{ \(fields.joined(separator: ", ")) }".utf8)
    }

    /// 서버가 커리큘럼 미등록에 실제로 내려주는 404 본문.
    static let curriculumNotRegisteredBody = errorBody(
        code: "CURRICULUM-0001",
        message: "커리큘럼을 찾을 수 없어요. 선택한 커리큘럼을 확인해주세요."
    )
}

private typealias RepositoryPair = (StudyRepository, StubNetworkRequesting)

/// 스터디 그룹 조회 테스트의 기본 보강 응답 — `memberId` 마다 `C{memberId}` / `닉{memberId}`.
///
/// 그룹 조회는 멤버마다 프로필을 부르므로, 기본값이 없으면 그 요청들이 FIFO 큐에서 다음 페이지
/// 응답을 먹어버린다. 챌린저 ID 해석 테스트처럼 FIFO 동작 자체를 검증할 때만 `nil` 을 넘긴다.
private let stubMemberProfileResponder:
    @Sendable (String) -> StubNetworkRequesting.Outcome = { memberID in
        .success(
            Fixture.success(
                Fixture.memberProfile(
                    memberID: memberID,
                    challengerID: "C\(memberID)",
                    nickname: "닉\(memberID)"
                )
            )
        )
    }

/// 프로필 보강이 항상 실패하는 responder — 보강 실패 폴백 경로 검증용.
private let failingMemberProfileResponder:
    @Sendable (String) -> StubNetworkRequesting.Outcome = { _ in
        .failure(StubNetworkRequesting.StubError.noOutcomeQueued)
    }

private func makeRepository(
    _ outcomes: [StubNetworkRequesting.Outcome],
    context: StudyContextProviding = StubStudyContext(),
    memberProfileResponder: (@Sendable (String) -> StubNetworkRequesting.Outcome)?
        = stubMemberProfileResponder
) -> RepositoryPair {
    let stub = StubNetworkRequesting(outcomes)
    stub.memberProfileResponder = memberProfileResponder
    let repository = StudyRepository(networkRequesting: stub, context: context)
    return (repository, stub)
}

private func makeRepository(
    _ outcome: StubNetworkRequesting.Outcome,
    context: StudyContextProviding = StubStudyContext(),
    memberProfileResponder: (@Sendable (String) -> StubNetworkRequesting.Outcome)?
        = stubMemberProfileResponder
) -> RepositoryPair {
    makeRepository(
        [outcome],
        context: context,
        memberProfileResponder: memberProfileResponder
    )
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

    // MARK: - 커리큘럼 미등록 승격

    /// 서버는 커리큘럼 미등록을 404 + `CURRICULUM-0001` 로 알린다. 학기 초에는 정상 상황이라
    /// 일반 서버 오류로 흘리면 사용자에게 "알 수 없는 오류" 카드로 보인다.
    ///
    /// 두 조회는 같은 `fetchCurriculum()` 헬퍼를 공유하므로 형제 대칭으로 함께 고정한다.
    ///
    /// 파라미터 타입 `CurriculumFetch` 가 file-private 이라 메서드도 fileprivate 로 맞춘다.
    @Test(
        "커리큘럼 미등록(404 CURRICULUM-0001)은 두 조회 모두 전용 도메인 에러로 승격된다",
        arguments: [CurriculumFetch.overview, .weeklyOptions]
    )
    fileprivate func promotesCurriculumNotRegistered(_ fetch: CurriculumFetch) async {
        let (sut, _) = makeRepository(
            .failure(
                NetworkError.requestFailed(
                    statusCode: 404,
                    data: Fixture.curriculumNotRegisteredBody
                )
            )
        )

        await #expect(throws: DomainError.curriculumNotRegistered) {
            try await fetch.run(sut)
        }
    }

    /// 승격 범위를 코드로 좁히지 않으면 401·5xx 같은 진짜 오류까지 "커리큘럼 준비 중"
    /// 안내로 뭉개져 전역 에러 처리를 우회한다.
    @Test(
        "미등록 코드가 아닌 실패는 원본 NetworkError 를 그대로 전파한다",
        arguments: [
            (404, Fixture.errorBody(code: "CURRICULUM-0014", message: "주차 없음")),
            (500, Fixture.errorBody(code: nil, message: "서버 오류")),
            (403, nil)
        ] as [(Int, Data?)]
    )
    func propagatesNonCurriculumFailures(statusCode: Int, body: Data?) async {
        let networkError = NetworkError.requestFailed(statusCode: statusCode, data: body)
        let (sut, _) = makeRepository(.failure(networkError))

        await #expect(throws: networkError) {
            try await sut.fetchCurriculumOverview()
        }
    }
}

/// ``fetchCurriculum()`` 헬퍼를 공유하는 두 공개 조회 — 미등록 승격을 형제 대칭으로 검증한다.
private enum CurriculumFetch: Sendable {
    case overview
    case weeklyOptions

    func run(_ sut: StudyRepository) async throws {
        switch self {
        case .overview:
            _ = try await sut.fetchCurriculumOverview()
        case .weeklyOptions:
            _ = try await sut.fetchWeeklyCurriculumOptions()
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
        #expect(stub.lastPrimaryPath == "/api/v1/study-groups/managed")
        #expect(stub.lastPrimaryMethod == .get)
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
        #expect(stub.primaryRequestCount == 2)
    }

    @Test("fetchStudyGroupDetails — hasNext 인데 커서가 없으면 무한 루프를 막고 중단한다")
    func fetchStudyGroupDetailsStopsOnMissingCursor() async throws {
        let page = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject], nextCursor: nil, hasNext: true
        )
        let (sut, stub) = makeRepository(.success(Fixture.success(page)))

        let details = try await sut.fetchStudyGroupDetails()

        #expect(details.count == 1)
        #expect(stub.primaryRequestCount == 1)  // 두 번째 페이지를 요청하지 않음
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
        #expect(stub.primaryCursors == [nil, "cursor-2"])
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
        #expect(stub.lastPrimaryPath == "/api/v1/study-groups/42")
    }

    /// 서버 계약 회귀 방어 — `studyGroupId` 키를 놓치면 `serverID` 가 비고, 운영진 화면이 모든
    /// 그룹을 "서버 미저장"으로 판정해 CRUD 가 통째로 막힌다.
    @Test("fetchStudyGroupDetail — serverID 가 비어 있지 않다 (CRUD 차단 회귀 방어)")
    func fetchStudyGroupDetailYieldsNonEmptyServerID() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.studyGroupDetailObject))
        )

        let info = try await sut.fetchStudyGroupDetail(groupId: "42")

        #expect(!info.serverID.isEmpty)
    }

    @Test("fetchStudyGroupDetail — 멤버 이름·학교는 서버 memberName/schoolName 에서 채운다")
    func fetchStudyGroupDetailMapsMemberNameAndSchool() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.studyGroupDetailObject))
        )

        let info = try await sut.fetchStudyGroupDetail(groupId: "42")

        #expect(info.mentors.first?.name == "멘토")
        #expect(info.members.first?.name == "챌린저")
        #expect(info.mentors.first?.university == "한성대")
    }

    // MARK: - 멤버 프로필 보강

    @Test("fetchStudyGroupDetail — 멤버마다 프로필을 조회해 challengerID/nickname 을 채운다")
    func fetchStudyGroupDetailSupplementsMembers() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(Fixture.studyGroupDetailObject))
        )

        let info = try await sut.fetchStudyGroupDetail(groupId: "42")

        #expect(info.mentors.first?.challengerID == "C10")
        #expect(info.mentors.first?.nickname == "닉10")
        #expect(info.members.first?.challengerID == "C20")
        #expect(info.members.first?.nickname == "닉20")
        #expect(
            Set(stub.memberProfilePaths) == [
                "/api/v1/member/profile/10",
                "/api/v1/member/profile/20"
            ]
        )
    }

    /// 같은 멤버가 여러 그룹·페이지에 등장해도 프로필은 한 번만 부른다.
    @Test("fetchStudyGroupDetailsPage — 중복 memberId 는 프로필을 한 번만 조회한다")
    func fetchStudyGroupDetailsPageDeduplicatesMemberProfileRequests() async throws {
        // 같은 멤버(10/20)를 가진 그룹 2개를 한 페이지에 담는다.
        let pageJSON = Fixture.studyGroupsPage(
            [Fixture.studyGroupDetailObject, Fixture.studyGroupDetailObject],
            nextCursor: nil,
            hasNext: false
        )
        let (sut, stub) = makeRepository(.success(Fixture.success(pageJSON)))

        _ = try await sut.fetchStudyGroupDetailsPage(cursor: nil, size: 20)

        #expect(stub.memberProfilePaths.count == 2)   // 4명이 아니라 고유 2명
    }

    /// 보강 실패가 목록 자체를 막으면 안 된다 — 그룹은 그대로 오고 두 값만 nil 로 남는다.
    @Test("fetchStudyGroupDetail — 프로필 조회가 실패해도 그룹은 반환되고 보강만 비어 있다")
    func fetchStudyGroupDetailSurvivesSupplementFailure() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.studyGroupDetailObject)),
            memberProfileResponder: failingMemberProfileResponder
        )

        let info = try await sut.fetchStudyGroupDetail(groupId: "42")

        #expect(info.serverID == "42")
        #expect(info.mentors.first?.name == "멘토")     // 그룹 응답 값은 그대로
        #expect(info.mentors.first?.challengerID == nil)
        #expect(info.mentors.first?.nickname == nil)
    }

    /// 일부 멤버만 실패해도 성공한 멤버의 보강은 살아 있어야 한다.
    @Test("fetchStudyGroupDetail — 일부 멤버 프로필만 실패하면 나머지 보강은 유지된다")
    func fetchStudyGroupDetailKeepsPartialSupplements() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.studyGroupDetailObject)),
            memberProfileResponder: { memberID in
                guard memberID == "10" else {
                    return .failure(StubNetworkRequesting.StubError.noOutcomeQueued)
                }
                return .success(
                    Fixture.success(
                        Fixture.memberProfile(
                            memberID: "10",
                            challengerID: "C10",
                            nickname: "닉10"
                        )
                    )
                )
            }
        )

        let info = try await sut.fetchStudyGroupDetail(groupId: "42")

        #expect(info.mentors.first?.challengerID == "C10")
        #expect(info.members.first?.challengerID == nil)
    }

    /// `challengerId` 와 `memberId` 는 서로 다른 식별자다. 보강 실패 시 `memberId` 로 대체하면
    /// 잘못된 대상으로 서버를 호출하게 되므로 `nil` 로 남겨야 한다.
    @Test("fetchStudyGroupDetail — 보강 실패 시 challengerID 를 memberId 로 대체하지 않는다")
    func fetchStudyGroupDetailDoesNotSubstituteMemberIDForChallengerID() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.studyGroupDetailObject)),
            memberProfileResponder: failingMemberProfileResponder
        )

        let info = try await sut.fetchStudyGroupDetail(groupId: "42")

        #expect(info.mentors.first?.challengerID != "10")
        #expect(info.members.first?.challengerID != "20")
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
            (
                preferred: Optional<String>.none,
                contextGisuId: Optional<String>.none,
                expected: "C7"
            )
        ]
    )
    func resolveChallengerIdAppliesPriority(
        preferred: String?,
        contextGisuId: String?,
        expected: String
    ) async throws {
        // FIFO 큐의 프로필 픽스처를 그대로 쓰기 위해 경로 분리 responder 를 끈다.
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.memberProfileObject)),
            context: StubStudyContext(gisuId: contextGisuId),
            memberProfileResponder: nil
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
            .success(Fixture.success(Fixture.memberProfileNoEligibleObject)),
            memberProfileResponder: nil
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

// MARK: - Suite: 제출 현황 조회 계약

@Suite("StudyRepository — 스터디원 제출 현황 조회 (도메인 규칙)")
struct StudyRepositorySubmissionTests {

    // MARK: - 엔드포인트 / 필터

    @Test("제출 현황은 v2 워크북 엔드포인트를 GET 으로 호출한다")
    func submissionsCallsWorkbookEndpoint() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(SubmissionFixture.page))
        )

        _ = try await sut.fetchStudyMemberSubmissions(
            studyGroupId: nil,
            weekNos: [],
            cursor: nil,
            size: 20
        )

        #expect(stub.lastPrimaryPath == "/api/v2/curriculums/workbook-submissions")
        #expect(stub.lastPrimaryMethod == .get)
    }

    @Test("커서는 서버가 준 값을 그대로 다음 요청에 실어 보낸다")
    func submissionsForwardsCursorVerbatim() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(SubmissionFixture.page))
        )

        _ = try await sut.fetchStudyMemberSubmissions(
            studyGroupId: nil,
            weekNos: [],
            cursor: "SGM-77",
            size: 20
        )

        #expect(stub.primaryCursors == ["SGM-77"])
    }

    // MARK: - 페이지 매핑

    @Test("커서 응답의 nextCursor/hasNext 가 도메인 페이지로 매핑된다")
    func submissionsMapsCursorMetadata() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(SubmissionFixture.page))
        )

        let page = try await sut.fetchStudyMemberSubmissions(
            studyGroupId: nil,
            weekNos: [],
            cursor: nil,
            size: 20
        )

        #expect(page.hasNext)
        #expect(page.nextCursor == "12")
        #expect(page.content.count == 2)
    }

    @Test("행은 스터디원 단위이고 주차는 각 행의 weeks 로 매핑된다")
    func submissionsMapsRowsAndWeeks() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(SubmissionFixture.page))
        )

        let page = try await sut.fetchStudyMemberSubmissions(
            studyGroupId: nil,
            weekNos: [],
            cursor: nil,
            size: 20
        )

        let first = try #require(page.content.first)
        #expect(first.studyGroupMemberId == "11")
        #expect(first.memberName == "박철수")
        #expect(first.weeks.count == 2)
    }

    @Test("워크북 미배포 인원도 행으로 오고 상세 진입이 막힌다")
    func submissionsIncludesNotDistributedMember() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.success(SubmissionFixture.page))
        )

        let page = try await sut.fetchStudyMemberSubmissions(
            studyGroupId: nil,
            weekNos: [],
            cursor: nil,
            size: 20
        )

        let second = try #require(page.content.last)
        let week = try #require(second.weeks.first)
        #expect(week.challengerWorkbookId == nil)
        #expect(week.status == .notSubmitted)
        #expect(second.managementItems.allSatisfy { !$0.canOpenDetail })
    }

    // MARK: - 그룹 이름 목록

    @Test("그룹 이름 목록은 names 엔드포인트를 호출하고 식별자를 String 으로 매핑한다")
    func groupNamesMapsIdentifiers() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(SubmissionFixture.groupNames))
        )

        let names = try await sut.fetchStudyGroupNames()

        #expect(stub.lastPrimaryPath == "/api/v1/study-groups/names")
        #expect(names.map(\.groupId) == ["3", "4"])
        #expect(names.map(\.name) == ["iOS A팀", "iOS B팀"])
    }

    // MARK: - 실패 전파

    @Test(
        "서버 실패 응답은 RepositoryError 로 전파된다 (형제 대칭)",
        arguments: [SubmissionEndpoint.submissions, .groupNames]
    )
    private func propagatesServerFailure(endpoint: SubmissionEndpoint) async {
        let (sut, _) = makeRepository(
            .success(Fixture.failureBody(code: "403", message: "권한 없음"))
        )

        await #expect(throws: RepositoryError.self) {
            try await endpoint.invoke(sut)
        }
    }
}

/// 제출 현황 계열 엔드포인트를 파라미터화해 실패 전파를 형제 대칭으로 검증하기 위한 디스패처.
private enum SubmissionEndpoint {
    case submissions
    case groupNames

    func invoke(_ repository: StudyRepository) async throws {
        switch self {
        case .submissions:
            _ = try await repository.fetchStudyMemberSubmissions(
                studyGroupId: "3",
                weekNos: ["1"],
                cursor: nil,
                size: 20
            )
        case .groupNames:
            _ = try await repository.fetchStudyGroupNames()
        }
    }
}

// MARK: - 제출 현황 Fixture

private enum SubmissionFixture {

    /// 스터디원 2명. 첫 행은 정수 ID + 워크북 배포, 둘째 행은 문자열 ID + **미배포**(null).
    /// 두 표기를 섞어 서버의 숫자/문자열 혼용을 한 응답에서 함께 검증한다.
    static let page = """
    {
      "content": [
        {
          "studyGroupMemberId": 11,
          "memberId": 101,
          "memberName": "박철수",
          "nickname": "철수",
          "schoolName": "한성대학교",
          "profileImageUrl": "https://cdn.umc/1.png",
          "studyGroupId": 3,
          "studyGroupName": "iOS A팀",
          "part": "IOS",
          "weeks": [
            {
              "weekNo": 1, "weeklyCurriculumId": 21,
              "challengerWorkbookId": 31, "status": "PASS", "isBest": true
            },
            {
              "weekNo": 2, "weeklyCurriculumId": 22,
              "challengerWorkbookId": 32, "status": "IN_PROGRESS", "isBest": false
            }
          ]
        },
        {
          "studyGroupMemberId": "12",
          "memberId": "102",
          "memberName": "이영희",
          "nickname": null,
          "schoolName": null,
          "profileImageUrl": null,
          "studyGroupId": "3",
          "studyGroupName": "iOS A팀",
          "part": "IOS",
          "weeks": [
            {
              "weekNo": "1", "weeklyCurriculumId": "21",
              "challengerWorkbookId": null, "status": "NOT_SUBMITTED", "isBest": false
            }
          ]
        }
      ],
      "nextCursor": 12,
      "hasNext": true
    }
    """

    static let groupNames = """
    {
      "studyGroups": [
        { "groupId": 3, "name": "iOS A팀" },
        { "groupId": "4", "name": "iOS B팀" }
      ]
    }
    """
}

#endif
