//
//  HomeRepositoryTests.swift
//  HomeDataTests
//
//  진짜 `HomeRepository`를 대상으로, 정본 프로필 조회 파이프라인(``MemberProfileRepositoryProtocol``)과
//  기수 상세 조회 네트워크 계층만 가짜(``MockMemberProfileRepository``/``StubHomeNetwork``)로 주입해
//  `Profile → HomeProfileResult` 매핑(세대 파생/포인트 분류/활동일 계산)과
//  `HomeRouter.getGisuDetail` 호출 계약을 검증한다.
//

import Foundation
import Testing
import Moya
import CoreDomain
import CoreNetwork
import UMCFoundation
import HomeDomain
@testable import HomeData

// MARK: - Test Doubles

/// ``HomeNetworkRequesting`` 가짜 구현.
///
/// 미리 설정한 결과(성공 본문 / 던질 에러)를 반환하고, 호출된 라우터의 경로·메서드·타깃을
/// 기록해 엔드포인트 계약을 검증할 수 있게 합니다. `target.path`/`target.method`만 읽어
/// `NetworkConfig.baseURL`(테스트 번들 `fatalError`)을 건드리지 않습니다.
private final class StubHomeNetwork: HomeNetworkRequesting, @unchecked Sendable {

    enum Outcome {
        case success(Data)
        case failure(Error)
    }

    private let outcome: Outcome
    private(set) var requestCount = 0
    private(set) var lastPath: String?
    private(set) var lastMethod: Moya.Method?
    private(set) var lastTarget: HomeRouter?

    init(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func request<T: TargetType>(_ target: T) async throws -> Response {
        requestCount += 1
        lastPath = target.path
        lastMethod = target.method
        lastTarget = target as? HomeRouter
        switch outcome {
        case .success(let data):
            return Response(statusCode: 200, data: data)
        case .failure(let error):
            throw error
        }
    }
}

/// ``MemberProfileRepositoryProtocol`` 가짜 구현.
private final class MockMemberProfileRepository: MemberProfileRepositoryProtocol, @unchecked Sendable {

    enum MockError: Error, Equatable {
        case notStubbed
    }

    var result: Result<Profile, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMyProfileCallCount = 0

    func fetchMyProfile() async throws -> Profile {
        fetchMyProfileCallCount += 1
        return try result.get()
    }
}

// MARK: - Fixtures

private enum Fixture {
    static func gisuDetailBody(gisuId: String, startAt: String) -> Data {
        Data("""
        {
          "success": true,
          "code": "200",
          "message": "성공",
          "result": { "gisuId": "\(gisuId)", "startAt": "\(startAt)" }
        }
        """.utf8)
    }
}

// MARK: - Tests

@Suite("HomeRepository — 정본 프로필 파이프라인 합성 검증")
struct HomeRepositoryTests {

    @Test("fetchMyProfile()이 Profile을 HomeProfileResult로 매핑한다 — 세대 파생/포인트 분류/활동일 계산")
    func fetchMyProfileMapsProfileToHomeProfileResult() async throws {
        let now = Date()
        var kstCalendar = Calendar(identifier: .gregorian)
        kstCalendar.timeZone = ServerDateTimeConverter.kstTimeZone
        let startDate = kstCalendar.date(byAdding: .day, value: -3, to: now)!
        let startAtString = ServerDateTimeConverter.toUTCDateTimeString(startDate)

        let olderPointDate = kstCalendar.date(byAdding: .day, value: -10, to: now)!
        let newerPointDate = kstCalendar.date(byAdding: .day, value: -1, to: now)!

        let rewardPoint = ProfileChallengerPoint(
            id: "point-reward",
            pointType: ChallengerPointType.bestWorkbook.rawValue,
            point: 2.0,
            description: "우수 워크북",
            createdAt: ServerDateTimeConverter.toUTCDateTimeString(olderPointDate)
        )
        let penaltyPoint = ProfileChallengerPoint(
            id: "point-penalty",
            pointType: "LATE_ATTENDANCE",
            point: -1.0,
            description: "지각",
            createdAt: ServerDateTimeConverter.toUTCDateTimeString(newerPointDate)
        )
        let challengerRecord = ProfileChallengerRecord(
            challengerId: "challenger-1",
            memberId: "1",
            gisu: "12",
            gisuId: "1002",
            chapterId: "chapter-1",
            chapterName: "한성대 지부",
            part: "IOS",
            schoolId: "5",
            schoolName: "한성대",
            name: "홍길동",
            nickname: "길동",
            email: "hong@example.com",
            profileImageLink: nil,
            status: .active,
            challengerPoints: [rewardPoint, penaltyPoint]
        )
        let profile = Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동",
            generations: ["11", "12"],
            roles: [],
            challengerRecords: [challengerRecord]
        )

        let memberProfileRepository = MockMemberProfileRepository()
        memberProfileRepository.result = .success(profile)
        let network = StubHomeNetwork(.success(Fixture.gisuDetailBody(gisuId: "1002", startAt: startAtString)))
        let repository = HomeRepository(
            networkRequesting: network,
            memberProfileRepository: memberProfileRepository
        )

        let result = try await repository.fetchMyProfile()

        #expect(result.memberId == "1")
        #expect(memberProfileRepository.fetchMyProfileCallCount == 1)

        let expectedDays = max(
            (kstCalendar.dateComponents(
                [.day],
                from: kstCalendar.startOfDay(for: startDate),
                to: kstCalendar.startOfDay(for: Date())
            ).day ?? 0) + 1,
            1
        )
        #expect(result.seasonTypes == [.gens(["11", "12"]), .days(expectedDays)])

        let expectedFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM.dd"
            formatter.timeZone = ServerDateTimeConverter.kstTimeZone
            formatter.locale = Locale(identifier: "ko_KR_POSIX")
            return formatter
        }()
        let expectedGeneration = HomeGeneration(
            gisuId: "1002",
            gen: "12",
            penaltyPoint: 1,
            rewardPoint: 2,
            pointLogs: [
                PointLog(
                    id: "point-penalty",
                    reason: "지각",
                    date: expectedFormatter.string(from: newerPointDate),
                    point: -1,
                    isReward: false
                ),
                PointLog(
                    id: "point-reward",
                    reason: "우수 워크북",
                    date: expectedFormatter.string(from: olderPointDate),
                    point: 2,
                    isReward: true
                ),
            ]
        )
        #expect(result.generations == [expectedGeneration])
    }

    @Test("활동일 계산이 HomeRouter.getGisuDetail(gisuId:)를 호출한다")
    func calculateActivityDaysCallsGetGisuDetail() async throws {
        let now = Date()
        let startAtString = ServerDateTimeConverter.toUTCDateTimeString(now)
        let record = ProfileChallengerRecord(
            challengerId: "challenger-1",
            memberId: "1",
            gisu: "12",
            gisuId: "1002",
            chapterId: nil,
            chapterName: nil,
            part: "IOS",
            schoolId: "5",
            schoolName: "한성대",
            name: nil,
            nickname: nil,
            email: nil,
            profileImageLink: nil,
            status: .active,
            challengerPoints: []
        )
        let profile = Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동",
            generations: ["12"],
            roles: [],
            challengerRecords: [record]
        )

        let memberProfileRepository = MockMemberProfileRepository()
        memberProfileRepository.result = .success(profile)
        let network = StubHomeNetwork(.success(Fixture.gisuDetailBody(gisuId: "1002", startAt: startAtString)))
        let repository = HomeRepository(
            networkRequesting: network,
            memberProfileRepository: memberProfileRepository
        )

        _ = try await repository.fetchMyProfile()

        #expect(network.requestCount == 1)
        #expect(network.lastPath == "/api/v1/gisu/1002")
        #expect(network.lastMethod == .get)
        if case .getGisuDetail(let gisuId) = network.lastTarget {
            #expect(gisuId == "1002")
        } else {
            Issue.record("lastTarget이 HomeRouter.getGisuDetail이 아닙니다: \(String(describing: network.lastTarget))")
        }
    }

    @Test("대상 기수가 없으면 네트워크 호출 없이 활동일을 0으로 반환한다")
    func fetchMyProfileWithNoTargetGisuSkipsNetworkCall() async throws {
        let profile = Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동",
            generations: [],
            roles: [],
            challengerRecords: []
        )

        let memberProfileRepository = MockMemberProfileRepository()
        memberProfileRepository.result = .success(profile)
        let network = StubHomeNetwork(.failure(MockMemberProfileRepository.MockError.notStubbed))
        let repository = HomeRepository(
            networkRequesting: network,
            memberProfileRepository: memberProfileRepository
        )

        let result = try await repository.fetchMyProfile()

        #expect(network.requestCount == 0)
        #expect(result.seasonTypes == [.days(0)])
        #expect(result.generations.isEmpty)
    }

    @Test("memberProfileRepository가 에러를 던지면 그대로 전파한다")
    func fetchMyProfilePropagatesProfileRepositoryError() async {
        let memberProfileRepository = MockMemberProfileRepository()
        memberProfileRepository.result = .failure(MockMemberProfileRepository.MockError.notStubbed)
        let network = StubHomeNetwork(.failure(MockMemberProfileRepository.MockError.notStubbed))
        let repository = HomeRepository(
            networkRequesting: network,
            memberProfileRepository: memberProfileRepository
        )

        await #expect(throws: MockMemberProfileRepository.MockError.notStubbed) {
            _ = try await repository.fetchMyProfile()
        }
    }
}
