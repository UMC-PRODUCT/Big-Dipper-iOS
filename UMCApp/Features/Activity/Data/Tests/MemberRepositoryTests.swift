//
//  MemberRepositoryTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/28/26.
//

import Testing
import Foundation
import Moya
import ActivityDomain
import CoreDomain
import UMCFoundation
@testable import ActivityData

#if DEBUG

// MARK: - Test Double

/// ``NetworkRequesting`` 가짜 구현 (FIFO outcome 큐).
///
/// 멤버 조회는 오프셋 검색 후 멤버별 프로필을 순차 호출하므로, 미리 설정한 결과를 순서대로
/// 반환하고 호출된 라우터의 경로·메서드를 기록해 엔드포인트 계약을 검증합니다.
private final class StubNetworkRequesting: NetworkRequesting, @unchecked Sendable {

    enum Outcome {
        case success(Data)
        case failure(Error)
    }

    enum StubError: Error {
        case noOutcomeQueued
    }

    private var outcomes: [Outcome]
    private(set) var requestedPaths: [String] = []
    private(set) var requestedMethods: [Moya.Method] = []

    var requestCount: Int { requestedPaths.count }
    var lastPath: String? { requestedPaths.last }
    var lastMethod: Moya.Method? { requestedMethods.last }

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func request<T: TargetType>(_ target: T) async throws -> Response {
        requestedPaths.append(target.path)
        requestedMethods.append(target.method)
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
}

/// 네트워크 실패 전파 검증용 테스트 에러.
private enum TestError: Error, Equatable {
    case network
}

/// ``MemberContextProviding`` 가짜 구현 — 학교·멤버·기수 식별자를 직접 지정합니다.
private struct StubMemberContext: MemberContextProviding {
    var schoolId: String?
    var currentMemberId: String?
    var gisuId: String?

    init(
        schoolId: String? = "5",
        currentMemberId: String? = "100",
        gisuId: String? = "70"
    ) {
        self.schoolId = schoolId
        self.currentMemberId = currentMemberId
        self.gisuId = gisuId
    }
}

// MARK: - Fixtures

private enum Fixture {

    /// 오프셋 검색 단일 항목.
    static func offsetItem(
        memberId: String,
        challengerId: String = "C100",
        part: String = "IOS",
        name: String = "홍길동",
        nickname: String = "닉",
        gisu: Int = 7,
        pointSum: Double = 3,
        roleTypes: [String] = ["CHALLENGER"]
    ) -> String {
        let roles = roleTypes.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {
          "challengerId": "\(challengerId)", "memberId": "\(memberId)", "gisuId": "70",
          "generation": \(gisu), "gisu": \(gisu), "part": "\(part)", "name": "\(name)",
          "nickname": "\(nickname)", "schoolName": "한성대", "pointSum": \(pointSum),
          "profileImageLink": null, "roleTypes": [\(roles)]
        }
        """
    }

    /// 오프셋 검색 결과 페이지.
    static func offsetPage(
        items: [String],
        page: Int = 0,
        hasNext: Bool = false
    ) -> String {
        """
        {
          "page": {
            "content": [\(items.joined(separator: ","))],
            "page": \(page), "size": 20, "totalElements": \(items.count),
            "totalPages": 1, "hasNext": \(hasNext), "hasPrevious": false
          }
        }
        """
    }

    /// 커서 검색 결과 페이지.
    static func cursorPage(
        items: [String],
        nextCursor: Int? = nil,
        hasNext: Bool = false
    ) -> String {
        let cursorValue = nextCursor.map(String.init) ?? "null"
        return """
        {
          "cursor": {
            "content": [\(items.joined(separator: ","))],
            "nextCursor": \(cursorValue), "hasNext": \(hasNext)
          },
          "partCounts": []
        }
        """
    }

    /// 단일 상벌점 항목.
    static func point(
        id: String,
        pointType: String,
        point: Double,
        createdAt: String,
        description: String = ""
    ) -> String {
        """
        {
          "id": "\(id)", "pointType": "\(pointType)", "point": \(point),
          "description": "\(description)", "createdAt": "\(createdAt)"
        }
        """
    }

    /// 챌린저 활동 레코드.
    static func record(
        memberId: String = "100",
        challengerId: String = "C100",
        gisu: Int,
        points: [String]
    ) -> String {
        """
        {
          "challengerId": "\(challengerId)", "memberId": "\(memberId)", "gisu": \(gisu),
          "gisuId": "70", "part": "IOS",
          "challengerPoints": [\(points.joined(separator: ","))], "points": []
        }
        """
    }

    /// 멤버 관리 프로필.
    static func memberProfile(
        id: String = "100",
        name: String = "홍길동",
        nickname: String = "닉",
        roleType: String = "SCHOOL_PART_LEADER",
        records: [String]
    ) -> String {
        """
        {
          "id": "\(id)", "name": "\(name)", "nickname": "\(nickname)", "schoolName": "한성대",
          "profileImageLink": null,
          "roles": [{ "challengerId": "C100", "roleType": "\(roleType)" }],
          "challengerRecords": [\(records.joined(separator: ","))]
        }
        """
    }

    /// 챌린저 프로필(포인트 히스토리 전용).
    static func challengerProfile(points: [String]) -> String {
        "{ \"challengerPoints\": [\(points.joined(separator: ","))] }"
    }

    /// 출석 현황 단일 일정.
    static func schedule(
        scheduleId: String,
        name: String,
        startsAt: String,
        participantMemberId: String,
        status: String
    ) -> String {
        """
        {
          "scheduleId": "\(scheduleId)", "name": "\(name)", "description": "",
          "startsAt": "\(startsAt)", "endsAt": "\(startsAt)", "isOnline": false,
          "location": null, "authorMemberId": "7", "attendancePolicy": null, "tags": [],
          "participants": [
            {
              "memberId": "\(participantMemberId)", "name": "참가자", "nickname": "닉",
              "profileImageUrl": null, "schoolId": "5", "schoolName": "한성대",
              "attendanceStatus": "\(status)", "isLocationVerified": true, "excuseReason": ""
            }
          ]
        }
        """
    }

    static func success(_ resultJSON: String) -> Data {
        Data("""
        { "success": true, "code": "200", "message": "성공", "result": \(resultJSON) }
        """.utf8)
    }

    static func successArray(_ objects: [String]) -> Data {
        success("[\(objects.joined(separator: ","))]")
    }

    static func failureBody(code: String?, message: String?) -> Data {
        var fields: [String] = ["\"success\": false"]
        if let code { fields.append("\"code\": \"\(code)\"") }
        if let message { fields.append("\"message\": \"\(message)\"") }
        return Data("{ \(fields.joined(separator: ", ")) }".utf8)
    }
}

private typealias RepositoryPair = (MemberRepository, StubNetworkRequesting)

private func makeRepository(
    _ outcomes: [StubNetworkRequesting.Outcome],
    context: MemberContextProviding = StubMemberContext()
) -> RepositoryPair {
    let stub = StubNetworkRequesting(outcomes)
    let repository = MemberRepository(networkRequesting: stub, context: context)
    return (repository, stub)
}

private func makeRepository(
    _ outcome: StubNetworkRequesting.Outcome,
    context: MemberContextProviding = StubMemberContext()
) -> RepositoryPair {
    makeRepository([outcome], context: context)
}

// MARK: - Suite: 멤버 목록 조회 계약

@Suite("MemberRepository — 멤버 목록 조회 (도메인 규칙)")
struct MemberRepositoryListTests {

    @Test("fetchMembersPage — 오프셋 검색 후 프로필을 보강하고 페이지 메타를 매핑한다")
    func fetchMembersPageMapsAndEnriches() async throws {
        let page = Fixture.offsetPage(items: [Fixture.offsetItem(memberId: "100")])
        let profile = Fixture.memberProfile(
            records: [Fixture.record(gisu: 7, points: [])]
        )
        let (sut, stub) = makeRepository([
            .success(Fixture.success(page)),
            .success(Fixture.success(profile))
        ])

        let result = try await sut.fetchMembersPage(page: 0)

        #expect(result.members.count == 1)
        #expect(result.members.first?.memberID == "100")
        #expect(result.members.first?.name == "홍길동")
        #expect(result.hasNext == false)
        #expect(result.currentPage == 0)
        #expect(stub.requestedPaths.first == "/api/v1/challenger/search/offset")
        #expect(stub.requestedPaths.last == "/api/v1/member/profile/100")
    }

    @Test("fetchMembers — schoolId 가 없으면 네트워크 호출 없이 도메인 에러를 던진다")
    func fetchMembersThrowsWhenNoSchool() async {
        let (sut, stub) = makeRepository([], context: StubMemberContext(schoolId: nil))

        await #expect(throws: DomainError.self) {
            try await sut.fetchMembers()
        }
        #expect(stub.requestCount == 0)
    }

    @Test("fetchMembers — hasNext 가 끝날 때까지 오프셋 페이지를 누적한다")
    func fetchMembersAccumulatesPages() async throws {
        let page0 = Fixture.offsetPage(
            items: [Fixture.offsetItem(memberId: "10")], page: 0, hasNext: true
        )
        let page1 = Fixture.offsetPage(
            items: [Fixture.offsetItem(memberId: "20")], page: 1, hasNext: false
        )
        let profile = Fixture.memberProfile(records: [Fixture.record(gisu: 7, points: [])])
        let (sut, stub) = makeRepository([
            .success(Fixture.success(page0)),
            .success(Fixture.success(page1)),
            .success(Fixture.success(profile)),
            .success(Fixture.success(profile))
        ])

        let members = try await sut.fetchMembers()

        #expect(members.count == 2)
        #expect(stub.requestCount == 4)        // 검색 2회 + 프로필 2회
    }

    @Test("fetchMembers — 빈 페이지가 hasNext:true 여도 무한 루프 없이 중단한다")
    func fetchMembersStopsOnEmptyPage() async throws {
        let emptyPage = Fixture.offsetPage(items: [], hasNext: true)
        let (sut, stub) = makeRepository(.success(Fixture.success(emptyPage)))

        let members = try await sut.fetchMembers()

        #expect(members.isEmpty)
        #expect(stub.requestCount == 1)        // 두 번째 페이지를 요청하지 않음
    }

    @Test("fetchMembersPage — 벌점 항목이 있으면 누적 벌점/상점을 분리 집계한다")
    func fetchMembersPageAggregatesPoints() async throws {
        let page = Fixture.offsetPage(items: [Fixture.offsetItem(memberId: "100")])
        let record = Fixture.record(
            gisu: 7,
            points: [
                Fixture.point(id: "1", pointType: "STUDY_LATE", point: -2,
                              createdAt: "2026-06-01T09:00:00.000Z"),
                Fixture.point(id: "2", pointType: "BLOG_CHALLENGE", point: 3,
                              createdAt: "2026-06-02T09:00:00.000Z")
            ]
        )
        let (sut, _) = makeRepository([
            .success(Fixture.success(page)),
            .success(Fixture.success(Fixture.memberProfile(records: [record])))
        ])

        let result = try await sut.fetchMembersPage(page: 0)
        let member = try #require(result.members.first)

        #expect(member.penalty == 2)            // abs(-2)
        #expect(member.rewardPoints == 3)       // abs(3)
        #expect(member.penaltyHistory.count == 1)
    }

    @Test("fetchMembersPage — 벌점 항목이 없으면 검색 pointSum 을 폴백 벌점으로 사용한다")
    func fetchMembersPageUsesFallbackPenalty() async throws {
        let page = Fixture.offsetPage(
            items: [Fixture.offsetItem(memberId: "100", pointSum: 5)]
        )
        let profile = Fixture.memberProfile(records: [Fixture.record(gisu: 7, points: [])])
        let (sut, _) = makeRepository([
            .success(Fixture.success(page)),
            .success(Fixture.success(profile))
        ])

        let result = try await sut.fetchMembersPage(page: 0)
        let member = try #require(result.members.first)

        #expect(member.penalty == 5)
        #expect(member.penaltyHistory.isEmpty)
    }

    // 검색 응답의 닉네임이 중간 모델에서 유실돼, 프로필 닉네임이 비면 '이름'이 닉네임 자리로 새던
    // 회귀(리뷰 지적). 닉네임은 프로필 우선, 프로필이 비면 검색 닉네임으로 폴백해야 한다(이름 아님).
    @Test(
        "fetchMembersPage — 닉네임은 프로필 우선, 프로필이 비면 검색 닉네임으로 폴백한다",
        arguments: [("프로필닉", "프로필닉"), ("", "검색닉")]
    )
    func fetchMembersPageResolvesNickname(
        _ profileNickname: String,
        _ expected: String
    ) async throws {
        let page = Fixture.offsetPage(
            items: [Fixture.offsetItem(memberId: "100", name: "홍길동", nickname: "검색닉")]
        )
        let profile = Fixture.memberProfile(
            name: "홍길동",
            nickname: profileNickname,
            records: [Fixture.record(gisu: 7, points: [])]
        )
        let (sut, _) = makeRepository([
            .success(Fixture.success(page)),
            .success(Fixture.success(profile))
        ])

        let member = try #require(try await sut.fetchMembersPage(page: 0).members.first)

        #expect(member.nickname == expected)
    }

    // 프로필 조회 실패 모드 두 가지 — 서버 거부(success:false)와 스키마 깨짐(malformed JSON).
    // 두 경우 모두 목록이 폴백 데이터로 "조용히 성공" 하지 않고 에러를 전파해야 한다(silent-failure 회귀 잠금).
    @Test(
        "fetchMembers — 프로필 조회 실패는 목록을 조용히 성공시키지 않고 전파한다",
        arguments: [
            Fixture.failureBody(code: "MEMBER401", message: "인증 만료"),
            Data("{ broken".utf8)
        ]
    )
    func fetchMembersPropagatesProfileFailure(_ profileFailure: Data) async {
        let page = Fixture.offsetPage(items: [Fixture.offsetItem(memberId: "100")])
        let (sut, _) = makeRepository([
            .success(Fixture.success(page)),
            .success(profileFailure)
        ])

        await #expect(throws: (any Error).self) {
            try await sut.fetchMembers()
        }
    }
}

// MARK: - Suite: 챌린저 커서 검색 계약

@Suite("MemberRepository — 챌린저 커서 검색 (도메인 규칙)")
struct MemberRepositoryChallengerSearchTests {

    @Test("커서 검색 엔드포인트를 GET 으로 호출한다")
    func callsCursorSearchEndpoint() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(Fixture.cursorPage(items: [])))
        )

        _ = try await sut.searchChallengers(keyword: "길동", cursor: nil, size: 50)

        #expect(stub.requestCount == 1)
        #expect(stub.lastPath == "/api/v1/challenger/search/cursor")
        #expect(stub.lastMethod == .get)
    }

    @Test("검색 항목을 ChallengerInfo 로 매핑하고 커서 정보를 보존한다")
    func mapsItemsToChallengerInfo() async throws {
        let page = Fixture.cursorPage(
            items: [
                Fixture.offsetItem(
                    memberId: "100",
                    challengerId: "C100",
                    part: "IOS",
                    name: "홍길동",
                    nickname: "길동",
                    gisu: 9
                )
            ],
            nextCursor: 12,
            hasNext: true
        )
        let (sut, _) = makeRepository(.success(Fixture.success(page)))

        let result = try await sut.searchChallengers(keyword: "길동", cursor: nil, size: 50)
        let challenger = try #require(result.challengers.first)

        #expect(challenger.memberId == "100")
        #expect(challenger.challengerId == "C100")
        #expect(challenger.name == "홍길동")
        #expect(challenger.nickname == "길동")
        #expect(challenger.schoolName == "한성대")
        #expect(challenger.part == .front(type: .ios))
        #expect(result.hasNext)
        #expect(result.nextCursor == 12)
    }

    @Test("기수는 '9기' 표시 문구가 아니라 챌린저 ID 해석에 쓰는 숫자 문자열이다")
    func mapsGenerationAsPlainNumber() async throws {
        let page = Fixture.cursorPage(
            items: [Fixture.offsetItem(memberId: "100", gisu: 9)]
        )
        let (sut, _) = makeRepository(.success(Fixture.success(page)))

        let result = try await sut.searchChallengers(keyword: nil, cursor: nil, size: 50)
        let challenger = try #require(result.challengers.first)

        // selectionKey 구성과 resolveChallengerId(preferredGeneration:) 비교가
        // 숫자 문자열을 전제한다.
        #expect(challenger.gen == "9")
        #expect(challenger.selectionKey == "100|9|IOS")
    }

    @Test("기수 정보가 없으면 gen 을 빈 문자열로 둔다")
    func mapsMissingGenerationAsEmpty() async throws {
        let item = """
        {
          "challengerId": "C100", "memberId": "100", "gisuId": "70",
          "part": "IOS", "name": "홍길동", "nickname": "길동",
          "schoolName": "한성대", "pointSum": 0, "roleTypes": []
        }
        """
        let (sut, _) = makeRepository(
            .success(Fixture.success(Fixture.cursorPage(items: [item])))
        )

        let result = try await sut.searchChallengers(keyword: nil, cursor: nil, size: 50)
        let challenger = try #require(result.challengers.first)

        // 빈 문자열은 호출부(OperatorStudyManagementViewModel)가 "기수 미지정"으로 읽는 신호다.
        #expect(challenger.gen.isEmpty)
    }

    @Test("memberId 가 없는 항목은 선택 키를 만들 수 없어 제외한다")
    func skipsItemsWithoutMemberId() async throws {
        let page = Fixture.cursorPage(
            items: [
                Fixture.offsetItem(memberId: ""),
                Fixture.offsetItem(memberId: "100")
            ]
        )
        let (sut, _) = makeRepository(.success(Fixture.success(page)))

        let result = try await sut.searchChallengers(keyword: nil, cursor: nil, size: 50)

        #expect(result.challengers.count == 1)
        #expect(result.challengers.first?.memberId == "100")
    }

    @Test("마지막 페이지는 hasNext 가 false 이고 커서가 없다")
    func mapsLastPage() async throws {
        let page = Fixture.cursorPage(
            items: [Fixture.offsetItem(memberId: "100")],
            nextCursor: nil,
            hasNext: false
        )
        let (sut, _) = makeRepository(.success(Fixture.success(page)))

        let result = try await sut.searchChallengers(keyword: nil, cursor: 3, size: 50)

        #expect(result.hasNext == false)
        #expect(result.nextCursor == nil)
    }

    @Test("네트워크 실패는 그대로 전파한다")
    func propagatesNetworkFailure() async {
        let (sut, _) = makeRepository(.failure(TestError.network))

        await #expect(throws: TestError.network) {
            _ = try await sut.searchChallengers(keyword: "길동", cursor: nil, size: 50)
        }
    }
}

// MARK: - Suite: 상벌점 부여 / 삭제 계약

@Suite("MemberRepository — 상벌점 부여/삭제 (도메인 규칙)")
struct MemberRepositoryPointMutationTests {

    @Test("grantPoint — 챌린저 포인트 엔드포인트로 POST 한다")
    func grantPointCallsEndpoint() async throws {
        let (sut, stub) = makeRepository(.success(Fixture.success("null")))

        try await sut.grantPoint(
            challengerId: "7", pointType: .bestWorkbook, pointValue: 2, description: "굿"
        )

        #expect(stub.requestCount == 1)
        #expect(stub.lastPath == "/api/v1/challenger/7/points")
        #expect(stub.lastMethod == .post)
    }

    @Test("deletePoint — 챌린저 포인트 삭제 엔드포인트로 DELETE 한다")
    func deletePointCallsEndpoint() async throws {
        let (sut, stub) = makeRepository(.success(Fixture.success("null")))

        try await sut.deletePoint(challengerPointId: "99")

        #expect(stub.requestCount == 1)
        #expect(stub.lastPath == "/api/v1/challenger/points/99")
        #expect(stub.lastMethod == .delete)
    }

    @Test("grantPoint — 본문 없는 2xx(빈 본문)도 성공으로 처리한다")
    func grantPointSucceedsOnEmptyBody() async throws {
        let (sut, stub) = makeRepository(.success(Data()))

        try await sut.grantPoint(
            challengerId: "7", pointType: .custom, pointValue: 1, description: "x"
        )

        #expect(stub.requestCount == 1)
    }

    @Test("grantPoint — success:false 면 serverError 를 던진다")
    func grantPointThrowsServerError() async {
        let (sut, _) = makeRepository(
            .success(Fixture.failureBody(code: "PT403", message: "권한 없음"))
        )

        await #expect(
            throws: RepositoryError.serverError(code: "PT403", message: "권한 없음")
        ) {
            try await sut.grantPoint(
                challengerId: "7", pointType: .out, pointValue: 1, description: "x"
            )
        }
    }

    @Test("deletePoint — success:false 면 serverError 를 던진다")
    func deletePointThrowsServerError() async {
        let (sut, _) = makeRepository(
            .success(Fixture.failureBody(code: "PT404", message: "포인트 없음"))
        )

        await #expect(
            throws: RepositoryError.serverError(code: "PT404", message: "포인트 없음")
        ) {
            try await sut.deletePoint(challengerPointId: "99")
        }
    }
}

// MARK: - Suite: 포인트 히스토리 / 기수 요약 계약

@Suite("MemberRepository — 포인트 히스토리·기수 요약 (도메인 규칙)")
struct MemberRepositoryHistoryTests {

    @Test("fetchPointHistory — WARNING 을 제외하고 최신순으로 매핑한다")
    func fetchPointHistoryExcludesWarningAndSorts() async throws {
        let profile = Fixture.challengerProfile(points: [
            Fixture.point(id: "1", pointType: "WARNING", point: 1,
                          createdAt: "2026-06-01T09:00:00.000Z"),
            Fixture.point(id: "2", pointType: "OUT", point: 1,
                          createdAt: "2026-06-03T09:00:00.000Z"),
            Fixture.point(id: "3", pointType: "BLOG_CHALLENGE", point: 3,
                          createdAt: "2026-06-02T09:00:00.000Z")
        ])
        let (sut, stub) = makeRepository(.success(Fixture.success(profile)))

        let history = try await sut.fetchPointHistory(challengerId: "7")

        #expect(history.count == 2)                       // WARNING 제외
        #expect(history.map(\.challengerPointId) == ["2", "3"])   // 최신순
        #expect(history.first?.pointType == .out)
        #expect(history.first?.penaltyScore == 1)
        #expect(stub.lastPath == "/api/v1/challenger/7")
    }

    @Test("fetchPointHistory — challengerPoints 가 없으면 루트 points 폴백을 사용한다")
    func fetchPointHistoryUsesPointsFallback() async throws {
        // 서버가 challengerPoints 대신 루트 points 키로 내려주는 형식(레거시 폴백).
        let pointsFallbackProfile = """
        { "points": [
          { "id": "5", "pointType": "STUDY_LATE", "point": -2,
            "description": "지각", "createdAt": "2026-06-01T09:00:00.000Z" }
        ] }
        """
        let (sut, _) = makeRepository(.success(Fixture.success(pointsFallbackProfile)))

        let history = try await sut.fetchPointHistory(challengerId: "7")

        #expect(history.count == 1)
        #expect(history.first?.challengerPointId == "5")
        #expect(history.first?.pointType == .studyLate)
    }

    @Test("fetchPointHistory — 네트워크 실패를 그대로 전파한다")
    func fetchPointHistoryPropagatesFailure() async {
        let (sut, _) = makeRepository(.failure(TestError.network))

        await #expect(throws: TestError.network) {
            try await sut.fetchPointHistory(challengerId: "7")
        }
    }

    @Test("fetchGenerationPointSummaries — 기수별 상/벌점을 분리해 오름차순 정렬한다")
    func fetchGenerationPointSummariesSplitsAndSorts() async throws {
        let record7 = Fixture.record(gisu: 7, points: [
            Fixture.point(id: "1", pointType: "BLOG_CHALLENGE", point: 3,
                          createdAt: "2026-06-01T09:00:00.000Z"),
            Fixture.point(id: "2", pointType: "STUDY_LATE", point: -2,
                          createdAt: "2026-06-01T09:00:00.000Z")
        ])
        let record8 = Fixture.record(gisu: 8, points: [
            Fixture.point(id: "3", pointType: "BEST_WORKBOOK", point: 2,
                          createdAt: "2026-06-01T09:00:00.000Z")
        ])
        let profile = Fixture.memberProfile(records: [record8, record7])
        let (sut, _) = makeRepository(.success(Fixture.success(profile)))

        let summaries = try await sut.fetchGenerationPointSummaries(memberId: "100")

        #expect(summaries.map(\.gisu) == [7, 8])
        #expect(summaries.map(\.reward) == [3, 2])
        #expect(summaries.map(\.penalty) == [2, 0])
    }

    @Test("fetchAllGenerations — 중복 없는 기수를 오름차순 텍스트로 결합한다")
    func fetchAllGenerationsJoinsUniqueGisu() async throws {
        let profile = Fixture.memberProfile(records: [
            Fixture.record(gisu: 8, points: []),
            Fixture.record(gisu: 7, points: [])
        ])
        let (sut, _) = makeRepository(.success(Fixture.success(profile)))

        let text = try await sut.fetchAllGenerations(memberId: "100")

        #expect(text == "7기, 8기")
    }
}

// MARK: - Suite: 출석 이력 조회 계약

@Suite("MemberRepository — 출석 이력 조회 (도메인 규칙)")
struct MemberRepositoryAttendanceTests {

    @Test("fetchAttendanceRecords — 일정을 시작시각 오름차순 주차로 매핑하고 멤버를 필터링한다")
    func fetchAttendanceRecordsFiltersAndOrders() async throws {
        let later = Fixture.schedule(
            scheduleId: "2", name: "2주차", startsAt: "2026-06-08T09:00:00.000Z",
            participantMemberId: "100", status: "PRESENT"
        )
        let earlier = Fixture.schedule(
            scheduleId: "1", name: "1주차", startsAt: "2026-06-01T09:00:00.000Z",
            participantMemberId: "100", status: "LATE"
        )
        let (sut, stub) = makeRepository(
            .success(Fixture.successArray([later, earlier]))
        )

        let records = try await sut.fetchAttendanceRecords(memberId: "100")

        #expect(records.map(\.sessionTitle) == ["1주차", "2주차"])   // startsAt 오름차순
        #expect(records.map(\.week) == [1, 2])
        #expect(records.first?.status == AttendanceStatus(serverStatus: "LATE"))
        #expect(stub.lastPath == "/api/v2/schedules/attendance")
    }

    @Test("fetchAttendanceRecords — memberId 가 비면 네트워크 호출 없이 빈 배열을 반환한다")
    func fetchAttendanceRecordsShortCircuitsOnEmptyId() async throws {
        let (sut, stub) = makeRepository([])

        let records = try await sut.fetchAttendanceRecords(memberId: "")

        #expect(records.isEmpty)
        #expect(stub.requestCount == 0)
    }
}

// MARK: - Suite: UserDefaults 컨텍스트 제공자 계약

@Suite("UserDefaultsMemberContextProvider — 식별자 해석 (도메인 규칙)")
struct UserDefaultsMemberContextProviderTests {

    /// 테스트마다 고유 suite 이름으로 격리해 잔여 값/병렬 실행 간섭을 차단합니다.
    private func makeDefaults(_ name: String) -> UserDefaults {
        let suiteName = "test.member.context.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("String 저장값을 우선 사용한다")
    func prefersStringValue() {
        let defaults = makeDefaults("prefers")
        defaults.set("42", forKey: "schoolId")
        defaults.set("100", forKey: "memberId")
        defaults.set("7", forKey: "gisuId")
        let context = UserDefaultsMemberContextProvider(defaults: defaults)

        #expect(context.schoolId == "42")
        #expect(context.currentMemberId == "100")
        #expect(context.gisuId == "7")
    }

    @Test("String 값이 없으면 레거시 Int 저장값을 문자열로 변환한다")
    func fallsBackToLegacyInt() {
        let defaults = makeDefaults("legacyInt")
        defaults.set(42, forKey: "schoolId")
        let context = UserDefaultsMemberContextProvider(defaults: defaults)

        #expect(context.schoolId == "42")
    }

    @Test("키가 없으면 nil 을 반환한다")
    func returnsNilWhenAbsent() {
        // 미설정(키 부재)이 실제 '미설정' 상태다. `UserDefaults.string(forKey:)` 는 저장된
        // 숫자를 문자열로 강제 변환하므로, 키 부재 케이스로 nil 분기를 검증한다.
        let defaults = makeDefaults("nilCase")
        let context = UserDefaultsMemberContextProvider(defaults: defaults)

        #expect(context.schoolId == nil)
        #expect(context.currentMemberId == nil)
        #expect(context.gisuId == nil)
    }
}

#endif
