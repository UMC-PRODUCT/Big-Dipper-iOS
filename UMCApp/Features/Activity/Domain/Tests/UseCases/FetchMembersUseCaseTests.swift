//
//  FetchMembersUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

#if DEBUG

// MARK: - Helpers

/// `memberID` 만 검증 대상이고, 나머지 필드는 init 충족용 임의 고정값입니다.
private func makeMemberItem(memberID: String) -> MemberManagementItem {
    MemberManagementItem(
        memberID: memberID,
        profile: nil,
        name: "테스트멤버",
        nickname: "닉네임",
        generation: "9기",
        school: "한성대학교",
        position: "파트원",
        part: .front(type: .ios),
        penalty: 0,
        badge: false,
        managementTeam: .challenger,
        attendanceRecords: [],
        penaltyHistory: []
    )
}

private func makeUseCase(
    repository: MockMemberRepository = MockMemberRepository()
) -> FetchMembersUseCase {
    FetchMembersUseCase(repository: repository)
}

// MARK: - Mocks

/// `MemberRepositoryProtocol` 의 모든 계약 메서드를 기록·제어하는 Mock.
/// `error` 가 설정되면 모든 메서드가 해당 에러를 던져 위임 facade 의 전파 경로를 검증합니다.
private final class MockMemberRepository: @unchecked Sendable, MemberRepositoryProtocol {

    enum MockError: Error {
        /// 에러 전파 경로 검증용 스텁 에러
        case stubbed
    }

    /// 챌린저 포인트 부여 호출 1건을 기록하는 값 타입
    struct GrantCall: Equatable {
        let challengerId: String
        let pointType: ChallengerPointType
        let pointValue: Int
        let description: String
    }

    // MARK: 반환값 스텁

    var fetchMembersResult: [MemberManagementItem] = []
    var fetchMembersPageResult = MemberPage(members: [], hasNext: false, currentPage: 0)
    var fetchPointHistoryResult: [OperatorMemberPenaltyHistory] = []
    var fetchAllGenerationsResult = ""
    var fetchGenerationPointSummariesResult: [GenerationPointSummary] = []
    var fetchAttendanceRecordsResult: [MemberAttendanceRecord] = []

    /// 설정 시 모든 메서드가 이 에러를 던진다 (에러 전파 검증용)
    var error: Error?

    // MARK: 호출 기록

    private(set) var fetchMembersCallCount = 0
    private(set) var fetchMembersPageCalls: [Int] = []
    private(set) var grantPointCalls: [GrantCall] = []
    private(set) var deletePointCalls: [String] = []
    private(set) var fetchPointHistoryCalls: [String] = []
    private(set) var fetchAllGenerationsCalls: [String] = []
    private(set) var fetchGenerationPointSummariesCalls: [String] = []
    private(set) var fetchAttendanceRecordsCalls: [String] = []

    // MARK: MemberRepositoryProtocol

    func fetchMembers() async throws -> [MemberManagementItem] {
        fetchMembersCallCount += 1
        if let error { throw error }
        return fetchMembersResult
    }

    func fetchMembersPage(page: Int) async throws -> MemberPage {
        fetchMembersPageCalls.append(page)
        if let error { throw error }
        return fetchMembersPageResult
    }

    func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        grantPointCalls.append(
            GrantCall(
                challengerId: challengerId,
                pointType: pointType,
                pointValue: pointValue,
                description: description
            )
        )
        if let error { throw error }
    }

    func deletePoint(challengerPointId: String) async throws {
        deletePointCalls.append(challengerPointId)
        if let error { throw error }
    }

    func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory] {
        fetchPointHistoryCalls.append(challengerId)
        if let error { throw error }
        return fetchPointHistoryResult
    }

    func fetchAllGenerations(memberId: String) async throws -> String {
        fetchAllGenerationsCalls.append(memberId)
        if let error { throw error }
        return fetchAllGenerationsResult
    }

    func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary] {
        fetchGenerationPointSummariesCalls.append(memberId)
        if let error { throw error }
        return fetchGenerationPointSummariesResult
    }

    func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord] {
        fetchAttendanceRecordsCalls.append(memberId)
        if let error { throw error }
        return fetchAttendanceRecordsResult
    }
}

// MARK: - 파라미터화 식별자

/// memberId 단일 인자를 받는 상세 조회 3종
private enum MemberDetailRead: CaseIterable, Sendable {
    case allGenerations
    case generationSummaries
    case attendanceRecords
}

/// 에러 전파 검증 대상 — 위임 facade 의 모든 메서드
private enum MemberMethod: CaseIterable, Sendable {
    case fetchMembers
    case fetchMembersPage
    case grantPoint
    case deletePoint
    case fetchPointHistory
    case fetchAllGenerations
    case fetchGenerationPointSummaries
    case fetchAttendanceRecords
}

private func callMethod(
    _ method: MemberMethod,
    on useCase: FetchMembersUseCase
) async throws {
    switch method {
    case .fetchMembers:
        _ = try await useCase.execute()
    case .fetchMembersPage:
        _ = try await useCase.executePage(page: 0)
    case .grantPoint:
        try await useCase.grantPoint(
            challengerId: "C-1",
            pointType: .bestWorkbook,
            pointValue: 2,
            description: ""
        )
    case .deletePoint:
        try await useCase.deletePoint(challengerPointId: "P-1")
    case .fetchPointHistory:
        _ = try await useCase.fetchPointHistory(challengerId: "C-1")
    case .fetchAllGenerations:
        _ = try await useCase.fetchAllGenerations(memberId: "M-1")
    case .fetchGenerationPointSummaries:
        _ = try await useCase.fetchGenerationPointSummaries(memberId: "M-1")
    case .fetchAttendanceRecords:
        _ = try await useCase.fetchAttendanceRecords(memberId: "M-1")
    }
}

// MARK: - 위임 계약

@Suite("FetchMembersUseCase — 멤버 관리 위임 계약 (도메인 규칙)")
struct FetchMembersUseCaseDelegationTests {

    @Test("execute — fetchMembers 결과를 그대로 반환하고 1회 호출")
    func executeReturnsRepositoryMembers() async throws {
        let repository = MockMemberRepository()
        repository.fetchMembersResult = [makeMemberItem(memberID: "M-1")]
        let useCase = makeUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result.map(\.memberID) == ["M-1"])
        #expect(repository.fetchMembersCallCount == 1)
    }

    @Test("executePage — page 인자를 그대로 위임하고 Repository 페이지를 반환")
    func executePageForwardsPageAndReturnsRepositoryPage() async throws {
        let repository = MockMemberRepository()
        repository.fetchMembersPageResult = MemberPage(
            members: [],
            hasNext: true,
            currentPage: 3
        )
        let useCase = makeUseCase(repository: repository)

        let page = try await useCase.executePage(page: 3)

        #expect(repository.fetchMembersPageCalls == [3])
        #expect(page.hasNext)
    }

    @Test("grantPoint — 4개 인자를 변형 없이 그대로 위임")
    func grantPointForwardsAllArguments() async throws {
        let repository = MockMemberRepository()
        let useCase = makeUseCase(repository: repository)

        try await useCase.grantPoint(
            challengerId: "C-9",
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "우수 워크북"
        )

        let expected = MockMemberRepository.GrantCall(
            challengerId: "C-9",
            pointType: .bestWorkbook,
            pointValue: 2,
            description: "우수 워크북"
        )
        #expect(repository.grantPointCalls == [expected])
    }

    @Test("deletePoint — challengerPointId 를 그대로 위임")
    func deletePointForwardsId() async throws {
        let repository = MockMemberRepository()
        let useCase = makeUseCase(repository: repository)

        try await useCase.deletePoint(challengerPointId: "P-3")

        #expect(repository.deletePointCalls == ["P-3"])
    }

    @Test("fetchPointHistory — challengerId 위임 + Repository 결과 반환")
    func fetchPointHistoryForwardsIdAndReturns() async throws {
        let repository = MockMemberRepository()
        let useCase = makeUseCase(repository: repository)

        _ = try await useCase.fetchPointHistory(challengerId: "C-7")

        #expect(repository.fetchPointHistoryCalls == ["C-7"])
    }

    @Test(
        "memberId 기반 상세 조회 3종이 memberId 를 그대로 위임",
        arguments: MemberDetailRead.allCases
    )
    fileprivate func detailReadsForwardMemberId(method: MemberDetailRead) async throws {
        let repository = MockMemberRepository()
        let useCase = makeUseCase(repository: repository)
        let memberId = "M-42"

        switch method {
        case .allGenerations:
            _ = try await useCase.fetchAllGenerations(memberId: memberId)
            #expect(repository.fetchAllGenerationsCalls == [memberId])
        case .generationSummaries:
            _ = try await useCase.fetchGenerationPointSummaries(memberId: memberId)
            #expect(repository.fetchGenerationPointSummariesCalls == [memberId])
        case .attendanceRecords:
            _ = try await useCase.fetchAttendanceRecords(memberId: memberId)
            #expect(repository.fetchAttendanceRecordsCalls == [memberId])
        }
    }
}

// MARK: - 에러 전파

@Suite("FetchMembersUseCase — Repository 에러 전파 (도메인 규칙)")
struct FetchMembersUseCaseErrorTests {

    @Test(
        "모든 메서드가 Repository 에러를 그대로 전파",
        arguments: MemberMethod.allCases
    )
    fileprivate func propagatesRepositoryError(method: MemberMethod) async {
        let repository = MockMemberRepository()
        repository.error = MockMemberRepository.MockError.stubbed
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: MockMemberRepository.MockError.stubbed) {
            try await callMethod(method, on: useCase)
        }
    }
}

#endif
