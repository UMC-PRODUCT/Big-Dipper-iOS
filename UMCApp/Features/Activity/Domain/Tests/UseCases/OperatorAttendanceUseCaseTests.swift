//
//  OperatorAttendanceUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Testing
@testable import ActivityDomain

#if DEBUG

// MARK: - Helpers

private func makeScheduleInfo(
    scheduleId: String = "100",
    participants: [ParticipantAttendance] = []
) -> ScheduleAttendanceInfo {
    ScheduleAttendanceInfo(
        scheduleId: scheduleId,
        name: "정기 세션",
        description: "",
        startsAt: Date(timeIntervalSince1970: 1_736_942_400),
        endsAt: Date(timeIntervalSince1970: 1_736_949_600),
        location: nil,
        isOnline: true,
        authorMemberId: "1",
        attendancePolicy: nil,
        tags: [],
        participants: participants
    )
}

private func makeDecisionResult(
    status: ParticipantAttendanceStatus = .present
) -> AttendanceDecisionResult {
    AttendanceDecisionResult(
        status: status,
        decidedAt: Date(timeIntervalSince1970: 1_000),
        decisionReason: nil,
        excuseReason: nil,
        latitude: nil,
        longitude: nil,
        decisionMakerMemberInfo: nil,
        isPendingDecision: false
    )
}

private func makeDecisionInput(
    isApproved: Bool = true,
    participantMemberId: String = "1",
    reason: String = ""
) -> AttendanceDecisionInput {
    AttendanceDecisionInput(
        isApproved: isApproved,
        participantMemberId: participantMemberId,
        reason: reason
    )
}

private func makeUseCase(
    repository: MockOperatorAttendanceRepository = MockOperatorAttendanceRepository()
) -> OperatorAttendanceUseCase {
    OperatorAttendanceUseCase(repository: repository)
}

// MARK: - Mocks

private final class MockOperatorAttendanceRepository: @unchecked Sendable,
    OperatorAttendanceRepositoryProtocol {

    // MARK: 스텁 결과

    var fetchAttendanceListResult: [ScheduleAttendanceInfo] = []
    var fetchAttendanceDetailResult: ScheduleAttendanceInfo = makeScheduleInfo()
    var decideAttendancesResult: [AttendanceDecisionResult] = []

    /// 설정 시 모든 메서드가 호출 기록 직후 이 에러를 던진다 (에러 전파 검증용)
    var errorToThrow: Error?

    // MARK: 호출 기록

    private(set) var fetchAttendanceListCalls: [(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    )] = []

    private(set) var fetchAttendanceDetailCalls: [(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    )] = []

    private(set) var decideAttendancesCalls: [(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    )] = []

    private(set) var updateScheduleLocationCalls: [(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    )] = []

    // MARK: Protocol

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo] {
        fetchAttendanceListCalls.append((from, to, attendanceStatus))
        if let errorToThrow {
            throw errorToThrow
        }
        return fetchAttendanceListResult
    }

    func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo {
        fetchAttendanceDetailCalls.append((scheduleId, attendanceStatus))
        if let errorToThrow {
            throw errorToThrow
        }
        return fetchAttendanceDetailResult
    }

    func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        decideAttendancesCalls.append((scheduleId, decisions))
        if let errorToThrow {
            throw errorToThrow
        }
        return decideAttendancesResult
    }

    func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        updateScheduleLocationCalls.append((scheduleId, locationName, latitude, longitude))
        if let errorToThrow {
            throw errorToThrow
        }
    }
}

private enum TestError: Error, Equatable {
    case boom
}

// MARK: - 조회 위임

@Suite("OperatorAttendanceUseCase — 조회 위임 (도메인 규칙)")
struct OperatorAttendanceUseCaseFetchTests {

    @Test("fetchAttendanceList — 기간·필터 인자 그대로 위임 + Repository 결과 반환")
    func fetchAttendanceListDelegates() async throws {
        let repository = MockOperatorAttendanceRepository()
        let expected = [makeScheduleInfo(scheduleId: "7"), makeScheduleInfo(scheduleId: "8")]
        repository.fetchAttendanceListResult = expected
        let useCase = makeUseCase(repository: repository)
        let from = Date(timeIntervalSince1970: 1_000)
        let to = Date(timeIntervalSince1970: 2_000)

        let result = try await useCase.fetchAttendanceList(
            from: from,
            to: to,
            attendanceStatus: .presentPending
        )

        #expect(result == expected)
        #expect(repository.fetchAttendanceListCalls.count == 1)
        let call = try #require(repository.fetchAttendanceListCalls.first)
        #expect(call.from == from)
        #expect(call.to == to)
        #expect(call.attendanceStatus == .presentPending)
    }

    @Test("fetchAttendanceList — nil 기간/필터를 변형 없이 그대로 전달")
    func fetchAttendanceListForwardsNil() async throws {
        let repository = MockOperatorAttendanceRepository()
        let useCase = makeUseCase(repository: repository)

        _ = try await useCase.fetchAttendanceList(
            from: nil,
            to: nil,
            attendanceStatus: nil
        )

        let call = try #require(repository.fetchAttendanceListCalls.first)
        #expect(call.from == nil)
        #expect(call.to == nil)
        #expect(call.attendanceStatus == nil)
    }

    @Test("fetchAttendanceDetail — scheduleId·필터 인자 그대로 위임 + Repository 결과 반환")
    func fetchAttendanceDetailDelegates() async throws {
        let repository = MockOperatorAttendanceRepository()
        let expected = makeScheduleInfo(scheduleId: "42")
        repository.fetchAttendanceDetailResult = expected
        let useCase = makeUseCase(repository: repository)

        let result = try await useCase.fetchAttendanceDetail(
            scheduleId: "42",
            attendanceStatus: .latePending
        )

        #expect(result == expected)
        let call = try #require(repository.fetchAttendanceDetailCalls.first)
        #expect(call.scheduleId == "42")
        #expect(call.attendanceStatus == .latePending)
    }
}

// MARK: - 액션 위임

@Suite("OperatorAttendanceUseCase — 액션 위임 (도메인 규칙)")
struct OperatorAttendanceUseCaseActionTests {

    @Test("decideAttendances — 결정 목록 그대로 위임 + Repository 결과 반환")
    func decideAttendancesDelegates() async throws {
        let repository = MockOperatorAttendanceRepository()
        let expected = [
            makeDecisionResult(status: .present),
            makeDecisionResult(status: .absent)
        ]
        repository.decideAttendancesResult = expected
        let useCase = makeUseCase(repository: repository)
        let decisions = [
            makeDecisionInput(isApproved: true, participantMemberId: "1", reason: ""),
            makeDecisionInput(isApproved: false, participantMemberId: "2", reason: "사유 불충분")
        ]

        let result = try await useCase.decideAttendances(
            scheduleId: "9",
            decisions: decisions
        )

        #expect(result == expected)
        let call = try #require(repository.decideAttendancesCalls.first)
        #expect(call.scheduleId == "9")
        #expect(call.decisions == decisions)
    }

    @Test("updateScheduleLocation — 위치 인자 4종 그대로 위임")
    func updateScheduleLocationDelegates() async throws {
        let repository = MockOperatorAttendanceRepository()
        let useCase = makeUseCase(repository: repository)

        try await useCase.updateScheduleLocation(
            scheduleId: "3",
            locationName: "한성대 상상관",
            latitude: 37.582,
            longitude: 127.010
        )

        #expect(repository.updateScheduleLocationCalls.count == 1)
        let call = try #require(repository.updateScheduleLocationCalls.first)
        #expect(call.scheduleId == "3")
        #expect(call.locationName == "한성대 상상관")
        #expect(call.latitude == 37.582)
        #expect(call.longitude == 127.010)
    }
}

// MARK: - 에러 전파

@Suite("OperatorAttendanceUseCase — 에러 전파 (도메인 규칙)")
struct OperatorAttendanceUseCaseErrorTests {

    @Test("Repository 조회 에러는 변환 없이 그대로 전파된다")
    func fetchPropagatesRepositoryError() async {
        let repository = MockOperatorAttendanceRepository()
        repository.errorToThrow = TestError.boom
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: TestError.boom) {
            _ = try await useCase.fetchAttendanceDetail(
                scheduleId: "1",
                attendanceStatus: nil
            )
        }
    }

    @Test("Repository 결정 에러는 삼키지 않고 그대로 전파된다")
    func decideAttendancesPropagatesRepositoryError() async {
        let repository = MockOperatorAttendanceRepository()
        repository.errorToThrow = TestError.boom
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: TestError.boom) {
            _ = try await useCase.decideAttendances(
                scheduleId: "1",
                decisions: []
            )
        }
    }

    @Test("Repository 위치변경 에러는 삼키지 않고 그대로 전파된다 (try? 회귀 가드)")
    func updateLocationPropagatesRepositoryError() async {
        let repository = MockOperatorAttendanceRepository()
        repository.errorToThrow = TestError.boom
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: TestError.boom) {
            try await useCase.updateScheduleLocation(
                scheduleId: "1",
                locationName: "x",
                latitude: 0,
                longitude: 0
            )
        }
    }
}

#endif
