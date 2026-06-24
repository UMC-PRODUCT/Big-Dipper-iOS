//
//  AttendanceRepositoryTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/10/26.
//

import Testing
import Foundation
import Moya
import ActivityDomain
import UMCFoundation
@testable import ActivityData

// MARK: - Test Double

#if DEBUG
/// ``NetworkRequesting`` 가짜 구현.
///
/// 미리 설정한 결과(성공 본문 / 던질 에러)를 반환하고, 호출된 라우터의 경로·메서드를
/// 기록해 엔드포인트 계약을 검증할 수 있게 합니다.
private final class StubNetworkRequesting: NetworkRequesting {

    enum Outcome {
        /// 200 응답으로 주어진 JSON 본문을 반환
        case success(Data)
        /// 요청 단계에서 에러를 던짐 (비-2xx 등)
        case failure(Error)
    }

    private let outcome: Outcome
    private(set) var requestCount = 0
    private(set) var lastPath: String?
    private(set) var lastMethod: Moya.Method?

    init(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func request<T: TargetType>(_ target: T) async throws -> Response {
        requestCount += 1
        lastPath = target.path
        lastMethod = target.method
        switch outcome {
        case .success(let data):
            return Response(statusCode: 200, data: data)
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Fixtures

private enum Fixture {

    /// 단일 출석 현황 DTO JSON (서버는 ID 를 문자열로 직렬화)
    static let scheduleAttendanceObject = """
    {
      "scheduleId": "42",
      "name": "1주차 정기 세션",
      "description": "오리엔테이션",
      "startsAt": "2026-06-01T09:00:00.000Z",
      "endsAt": "2026-06-01T11:00:00.000Z",
      "isOnline": false,
      "location": { "latitude": 37.5, "longitude": 127.0, "locationName": "한성대" },
      "authorMemberId": "7",
      "attendancePolicy": {
        "checkInStartAt": "2026-06-01T08:30:00.000Z",
        "onTimeEndAt": "2026-06-01T09:10:00.000Z",
        "lateEndAt": "2026-06-01T09:30:00.000Z"
      },
      "tags": ["LEADERSHIP"],
      "participants": [
        {
          "memberId": "100", "name": "홍길동", "nickname": "길동",
          "profileImageUrl": "https://img/1.png", "schoolId": "5", "schoolName": "한성대",
          "attendanceStatus": "PRESENT", "isLocationVerified": true, "excuseReason": ""
        },
        {
          "memberId": "101", "name": "김철수", "nickname": "철수",
          "profileImageUrl": null, "schoolId": "5", "schoolName": "한성대",
          "attendanceStatus": "EXCUSED_PENDING", "isLocationVerified": false, "excuseReason": "병결"
        }
      ]
    }
    """

    /// 숫자 ID 로 내려오는 변형 (유연 디코딩 검증용)
    static let scheduleAttendanceNumericIDObject = """
    {
      "scheduleId": 42,
      "name": "수치 ID 세션",
      "description": "",
      "startsAt": "2026-06-01T09:00:00.000Z",
      "endsAt": "2026-06-01T11:00:00.000Z",
      "isOnline": true,
      "location": null,
      "authorMemberId": 7,
      "attendancePolicy": null,
      "tags": [],
      "participants": [
        {
          "memberId": 100, "name": "수치", "nickname": "넘버",
          "schoolId": 5, "schoolName": "한성대",
          "attendanceStatus": "LATE", "isLocationVerified": true
        }
      ]
    }
    """

    /// 승인자 정보 포함 결정 응답 DTO JSON
    static let decisionWithMakerObject = """
    {
      "status": "PRESENT",
      "decidedAt": "2026-06-01T09:05:00.000Z",
      "decisionReason": "정상 출석",
      "excuseReason": null,
      "hasDecisionMakerMember": true,
      "isPendingDecision": false,
      "latitude": 37.5,
      "longitude": 127.0,
      "decisionMakerMemberInfo": {
        "memberId": "7", "name": "운영진", "nickname": "운영",
        "schoolId": "5", "schoolName": "한성대"
      }
    }
    """

    /// 승인자 정보는 없는데 서버 플래그만 true 인 모순 응답
    /// (도메인은 `decisionMakerMemberInfo == nil` 로 파생해 false 여야 함)
    static let decisionFlagTrueButNoMakerObject = """
    {
      "status": "PRESENT_PENDING",
      "decidedAt": null,
      "decisionReason": "",
      "excuseReason": "",
      "hasDecisionMakerMember": true,
      "isPendingDecision": true,
      "latitude": null,
      "longitude": null,
      "decisionMakerMemberInfo": null
    }
    """

    /// 미지원 상태 문자열 (`.unknown` 폴백 검증용)
    static let decisionUnknownStatusObject = """
    {
      "status": "BRAND_NEW_STATUS",
      "isPendingDecision": false,
      "hasDecisionMakerMember": false
    }
    """

    static func success(_ resultJSON: String) -> Data {
        Data("""
        { "success": true, "code": "200", "message": "성공", "result": \(resultJSON) }
        """.utf8)
    }

    static func successArray(_ objects: [String]) -> Data {
        success("[\(objects.joined(separator: ","))]")
    }

    static func successVoid() -> Data {
        Data("""
        { "success": true, "code": "200", "message": "성공", "result": null }
        """.utf8)
    }

    static func failureBody(code: String?, message: String?, result: String?) -> Data {
        var fields: [String] = ["\"success\": false"]
        if let code { fields.append("\"code\": \"\(code)\"") }
        if let message { fields.append("\"message\": \"\(message)\"") }
        if let result { fields.append("\"result\": \"\(result)\"") }
        return Data("{ \(fields.joined(separator: ", ")) }".utf8)
    }
}

private typealias RepositoryPair = (AttendanceRepository, StubNetworkRequesting)

private func makeRepository(_ outcome: StubNetworkRequesting.Outcome) -> RepositoryPair {
    let stub = StubNetworkRequesting(outcome)
    let repository = AttendanceRepository(networkRequesting: stub)
    return (repository, stub)
}

private func utcDate(_ iso: String) -> Date? {
    ServerDateTimeConverter.parseUTCDateTime(iso)
}

/// 챌린저 단일 출석 액션 — `requestAttendance`(GPS) 와 `submitExcuse`(사유).
///
/// 두 메서드는 동일한 `performAttendanceAction` 을 공유하므로 성공 매핑·엔드포인트·
/// 에러 승격을 하나의 파라미터화 테스트로 함께 검증한다.
private enum ChallengerAction: CaseIterable, CustomTestStringConvertible {
    case request
    case excuse

    var expectedPath: String {
        switch self {
        case .request: "/api/v2/schedules/42/attendances/request"
        case .excuse: "/api/v2/schedules/42/attendances/excuse"
        }
    }

    var testDescription: String {
        switch self {
        case .request: "requestAttendance"
        case .excuse: "submitExcuse"
        }
    }

    /// 고정 좌표/사유로 해당 액션을 호출한다 (성공·실패 outcome 은 stub 가 결정).
    func invoke(on sut: AttendanceRepository) async throws -> AttendanceDecisionResult {
        switch self {
        case .request:
            try await sut.requestAttendance(
                scheduleId: "42", latitude: 37.5, longitude: 127.0, locationVerified: true
            )
        case .excuse:
            try await sut.submitExcuse(
                scheduleId: "42", excuseReason: "사유", isVerified: true,
                latitude: 37.5, longitude: 127.0
            )
        }
    }
}

// MARK: - Suite: 조회 매핑 계약

@Suite("AttendanceRepository — 조회 매핑 (도메인 규칙)")
struct AttendanceRepositoryFetchTests {

    // MARK: - fetchAttendanceList

    @Test("fetchAttendanceList — 성공 응답을 도메인 목록으로 매핑하고 출석 엔드포인트를 호출한다")
    func fetchAttendanceListMapsSuccess() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.successArray([Fixture.scheduleAttendanceObject]))
        )

        let list = try await sut.fetchAttendanceList(from: nil, to: nil, attendanceStatus: nil)

        let info = try #require(list.first)
        #expect(list.count == 1)
        #expect(info.scheduleId == "42")
        #expect(info.authorMemberId == "7")
        #expect(info.participants.count == 2)
        #expect(stub.lastPath == "/api/v2/schedules/attendance")
        #expect(stub.lastMethod == .get)
    }

    @Test("fetchAttendanceList — 참여자 상태/사유/위치를 도메인 규칙대로 정규화한다")
    func fetchAttendanceListNormalizesParticipants() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.successArray([Fixture.scheduleAttendanceObject]))
        )

        let info = try #require(try await sut.fetchAttendanceList(
            from: nil, to: nil, attendanceStatus: nil
        ).first)

        let present = info.participants[0]
        let pending = info.participants[1]
        #expect(present.memberId == "100")
        #expect(present.attendanceStatus == .present)
        #expect(present.excuseReason == nil)        // 빈 문자열 → nil 정규화
        #expect(pending.attendanceStatus == .excusedPending)
        #expect(pending.excuseReason == "병결")
        #expect(pending.profileImageURL == "")      // null → "" 정규화
    }

    @Test("fetchAttendanceList — 일시·장소·정책을 파싱해 매핑한다")
    func fetchAttendanceListMapsScheduleMeta() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.successArray([Fixture.scheduleAttendanceObject]))
        )

        let info = try #require(try await sut.fetchAttendanceList(
            from: nil, to: nil, attendanceStatus: nil
        ).first)

        #expect(info.startsAt == utcDate("2026-06-01T09:00:00.000Z"))
        #expect(info.endsAt == utcDate("2026-06-01T11:00:00.000Z"))
        #expect(info.location?.locationName == "한성대")
        #expect(info.attendancePolicy?.checkInStartAt == utcDate("2026-06-01T08:30:00.000Z"))
    }

    @Test("fetchAttendanceList — ID 가 숫자로 내려와도 String 으로 디코딩한다")
    func fetchAttendanceListDecodesNumericIDsAsString() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.successArray([Fixture.scheduleAttendanceNumericIDObject]))
        )

        let info = try #require(try await sut.fetchAttendanceList(
            from: nil, to: nil, attendanceStatus: nil
        ).first)

        #expect(info.scheduleId == "42")
        #expect(info.authorMemberId == "7")
        #expect(info.participants.first?.memberId == "100")
        #expect(info.participants.first?.schoolId == "5")
        #expect(info.location == nil)            // null → 비대면
        #expect(info.attendancePolicy == nil)    // null → 정책 미부착
    }

    // MARK: - fetchAttendanceDetail

    @Test("fetchAttendanceDetail — 단일 응답을 매핑하고 scheduleId 를 path 에 보간한다")
    func fetchAttendanceDetailMapsSuccess() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(Fixture.scheduleAttendanceObject))
        )

        let info = try await sut.fetchAttendanceDetail(scheduleId: "42", attendanceStatus: nil)

        #expect(info.scheduleId == "42")
        #expect(info.presentCount == 1)          // PRESENT 1명 (EXCUSED_PENDING 제외)
        #expect(info.pendingCount == 1)
        #expect(stub.lastPath == "/api/v2/schedules/42/attendance")
    }

    @Test("fetchAttendanceDetail — isSuccess:false 면 RepositoryError.serverError 를 던진다")
    func fetchAttendanceDetailThrowsServerError() async {
        let (sut, _) = makeRepository(
            .success(Fixture.failureBody(code: "S404", message: "일정 없음", result: nil))
        )

        await #expect(throws: RepositoryError.serverError(code: "S404", message: "일정 없음")) {
            try await sut.fetchAttendanceDetail(scheduleId: "42", attendanceStatus: nil)
        }
    }
}

// MARK: - Suite: 결정 매핑 계약

@Suite("AttendanceRepository — 결정 매핑 (도메인 규칙)")
struct AttendanceRepositoryDecisionTests {

    // MARK: - decideAttendances

    @Test("decideAttendances — 승인자 정보를 매핑하고 결정 엔드포인트를 호출한다")
    func decideAttendancesMapsMaker() async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.successArray([Fixture.decisionWithMakerObject]))
        )

        let results = try await sut.decideAttendances(
            scheduleId: "42",
            decisions: [.init(isApproved: true, participantMemberId: "100", reason: "승인")]
        )

        let result = try #require(results.first)
        #expect(result.status == .present)
        #expect(result.decisionMakerMemberInfo?.memberId == "7")
        #expect(result.hasDecisionMakerMember == true)
        #expect(result.decidedAt == utcDate("2026-06-01T09:05:00.000Z"))
        #expect(stub.lastPath == "/api/v2/schedules/42/attendances/decide")
        #expect(stub.lastMethod == .post)
    }

    @Test("decideAttendances — 승인자 정보가 없으면 서버 플래그와 무관하게 hasDecisionMakerMember 는 false")
    func decideAttendancesDerivesHasMakerFromInfo() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.successArray([Fixture.decisionFlagTrueButNoMakerObject]))
        )

        let result = try #require(try await sut.decideAttendances(
            scheduleId: "42",
            decisions: [.init(isApproved: false, participantMemberId: "100", reason: "")]
        ).first)

        // 서버가 hasDecisionMakerMember:true 를 보냈지만 info 가 null → 도메인은 false 로 파생
        #expect(result.decisionMakerMemberInfo == nil)
        #expect(result.hasDecisionMakerMember == false)
        #expect(result.isPendingDecision == true)
        #expect(result.decisionReason == nil)    // 빈 문자열 → nil
    }

    @Test("decideAttendances — 미지원 상태 문자열은 .unknown 으로 폴백한다")
    func decideAttendancesFallsBackToUnknown() async throws {
        let (sut, _) = makeRepository(
            .success(Fixture.successArray([Fixture.decisionUnknownStatusObject]))
        )

        let result = try #require(try await sut.decideAttendances(
            scheduleId: "42",
            decisions: [.init(isApproved: true, participantMemberId: "100", reason: "")]
        ).first)

        #expect(result.status == .unknown)
    }

    // MARK: - 챌린저 출석 액션 (성공)

    @Test(
        "챌린저 출석 액션 — 성공 응답을 매핑하고 올바른 엔드포인트를 호출한다",
        arguments: ChallengerAction.allCases
    )
    fileprivate func challengerActionMapsSuccess(_ action: ChallengerAction) async throws {
        let (sut, stub) = makeRepository(
            .success(Fixture.success(Fixture.decisionWithMakerObject))
        )

        let result = try await action.invoke(on: sut)

        #expect(result.status == .present)
        #expect(stub.lastPath == action.expectedPath)
        #expect(stub.lastMethod == .post)
    }
}

// MARK: - Suite: 에러 매핑 계약

@Suite("AttendanceRepository — 출석 액션 에러 매핑 (서버 contract)")
struct AttendanceRepositoryErrorMappingTests {

    @Test(
        "챌린저 출석 액션 — '이미 출석' 본문(requestFailed)을 attendanceAlreadySubmitted 로 승격한다",
        arguments: zip(
            ChallengerAction.allCases,
            ["이미 출석 처리된 일정입니다.", "이미 출석 처리되었습니다."]
        )
    )
    fileprivate func challengerActionMapsAlreadySubmitted(
        _ action: ChallengerAction, resultMessage: String
    ) async {
        let body = Fixture.failureBody(
            code: "ATTEND409", message: "출석 처리 실패", result: resultMessage
        )
        let (sut, _) = makeRepository(
            .failure(NetworkError.requestFailed(statusCode: 409, data: body))
        )

        await #expect(throws: DomainError.attendanceAlreadySubmitted) {
            try await action.invoke(on: sut)
        }
    }

    @Test("requestAttendance — 일반 실패 본문은 RepositoryError.serverError(메시지) 로 변환한다")
    func requestAttendanceMapsGenericServerError() async {
        let body = Fixture.failureBody(code: "ATTEND400", message: "잘못된 요청입니다.", result: "")
        let (sut, _) = makeRepository(
            .failure(NetworkError.requestFailed(statusCode: 400, data: body))
        )
        let expected = RepositoryError.serverError(code: "ATTEND400", message: "잘못된 요청입니다.")

        await #expect(throws: expected) {
            try await sut.requestAttendance(
                scheduleId: "42", latitude: 37.5, longitude: 127.0, locationVerified: true
            )
        }
    }

    @Test("requestAttendance — 본문 없는 NetworkError 는 원본 그대로 전파한다")
    func requestAttendancePropagatesNonMappableError() async {
        let (sut, _) = makeRepository(.failure(NetworkError.timeout))

        await #expect(throws: NetworkError.timeout) {
            try await sut.requestAttendance(
                scheduleId: "42", latitude: 37.5, longitude: 127.0, locationVerified: true
            )
        }
    }
}

// MARK: - Suite: void 액션 계약

@Suite("AttendanceRepository — 위치 변경 (void 계약)")
struct AttendanceRepositoryUpdateLocationTests {

    @Test("updateScheduleLocation — 성공 시 throw 없이 완료하고 PATCH 엔드포인트를 호출한다")
    func updateScheduleLocationSucceeds() async throws {
        let (sut, stub) = makeRepository(.success(Fixture.successVoid()))

        try await sut.updateScheduleLocation(
            scheduleId: "42", locationName: "한성대입구역", latitude: 37.5, longitude: 127.0
        )

        #expect(stub.requestCount == 1)
        #expect(stub.lastPath == "/api/v2/schedules/42")
        #expect(stub.lastMethod == .patch)
    }

    @Test("updateScheduleLocation — isSuccess:false 면 RepositoryError.serverError 를 던진다")
    func updateScheduleLocationThrowsServerError() async {
        let (sut, _) = makeRepository(
            .success(Fixture.failureBody(code: "S403", message: "권한 없음", result: nil))
        )

        await #expect(throws: RepositoryError.serverError(code: "S403", message: "권한 없음")) {
            try await sut.updateScheduleLocation(
                scheduleId: "42", locationName: "x", latitude: 0, longitude: 0
            )
        }
    }
}
#endif
