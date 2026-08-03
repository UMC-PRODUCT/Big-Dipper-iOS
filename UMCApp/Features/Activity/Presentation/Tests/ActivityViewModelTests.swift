//
//  ActivityViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import Foundation
import HomeDomain
import Testing
import UMCFoundation
@testable import ActivityPresentation

// Mock 과 이를 사용하는 스위트 전체를 하나의 가드 안에 둔다.
#if DEBUG

// MARK: - Helpers

/// 결정론적 기준 시각 (epoch 100_000) — wall-clock 비의존
private let fixedNow = Date(timeIntervalSince1970: 100_000)

private func makeSchedule(
    scheduleId: String = "S-1",
    name: String = "1주차 OT",
    startsAt: Date = fixedNow,
    location: ScheduleLocation? = nil,
    attendanceStatus: ScheduleAttendanceStatus? = nil,
    isAttendanceChecked: Bool = false
) -> ScheduleDetailData {
    ScheduleDetailData(
        scheduleId: scheduleId,
        name: name,
        description: "",
        tags: [],
        startsAt: startsAt,
        endsAt: startsAt.addingTimeInterval(3_600),
        isParticipant: true,
        location: location,
        attendanceStatus: attendanceStatus,
        isAttendanceChecked: isAttendanceChecked
    )
}

@MainActor
private func makeViewModel(
    attendance: MockRootAttendanceUseCase = MockRootAttendanceUseCase(),
    userId: MockFetchUserIdUseCase = MockFetchUserIdUseCase(),
    classifier: MockClassifyScheduleUseCase = MockClassifyScheduleUseCase()
) -> ActivityViewModel {
    ActivityViewModel(
        challengerAttendanceUseCase: attendance,
        fetchUserIdUseCase: userId,
        classifyScheduleUseCase: classifier
    )
}

/// 적재된 세션 목록 — `.loaded` 가 아니면 `#require` 가 그 자리에서 실패시킨다.
@MainActor
private func loadedSessions(_ viewModel: ActivityViewModel) throws -> [Session] {
    try #require(viewModel.sessionsState.value)
}

private struct SampleError: Error {}

// MARK: - Mocks

/// 루트가 쓰는 일정 조회만 제어하고 나머지 출석 액션은 no-op 인 스텁.
private final class MockRootAttendanceUseCase: @unchecked Sendable,
    ChallengerAttendanceUseCaseProtocol {

    var isInsideGeofence: Bool = true
    var isLocationAuthorized: Bool = true

    var availableSchedulesResult: Result<[ScheduleDetailData], Error> = .success([])
    private(set) var fetchAvailableSchedulesCallCount: Int = 0

    /// `true` 면 일정 조회가 ``openAvailableSchedulesGate()`` 전까지 반환하지 않는다.
    ///
    /// 재진입 가드처럼 "요청이 진행 중인 순간" 을 관찰해야 하는 테스트에서 쓴다. 조회는
    /// MainActor 밖에서 재개되므로 continuation 등록 대신 플래그 폴링으로 구현한다
    /// (형제 스위트 `ChallengerAttendanceViewModelTests` 와 같은 방식).
    var gateAvailableSchedules: Bool = false

    func fetchAvailableSchedules(now: Date) async throws -> [ScheduleDetailData] {
        fetchAvailableSchedulesCallCount += 1
        while gateAvailableSchedules {
            await Task.yield()
        }
        return try availableSchedulesResult.get()
    }

    /// 게이트에 걸려 있던 일정 조회를 재개시킨다.
    func openAvailableSchedulesGate() {
        gateAvailableSchedules = false
    }

    func fetchMyHistory(now: Date) async throws -> [ScheduleDetailData] { [] }

    func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: String
    ) async throws -> Attendance {
        Attendance(sessionId: sessionId, userId: userId, type: .gps, status: .present)
    }

    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        Attendance(sessionId: sessionId, userId: userId, type: .reason, status: .pendingApproval)
    }

    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        Attendance(sessionId: sessionId, userId: userId, type: .reason, status: .pendingApproval)
    }

    func isWithinAttendanceTime(info: SessionInfo, now: Date) -> AttendanceTimeWindow { .onTime }

    func getAddressToCurrentLocation() async throws -> Address {
        Address(fullAddress: "서울특별시 성북구", city: "서울특별시", district: "성북구")
    }

    func stopGeofenceMonitoring() async {}
}

private final class MockFetchUserIdUseCase: @unchecked Sendable, FetchUserIdUseCaseProtocol {

    var result: Result<UserID, Error> = .success(UserID(value: "U-1"))
    private(set) var callCount: Int = 0

    func execute() async throws -> UserID {
        callCount += 1
        return try result.get()
    }
}

private final class MockClassifyScheduleUseCase: @unchecked Sendable,
    ClassifyScheduleUseCaseProtocol {

    var categoriesByTitle: [String: ScheduleIconCategory] = [:]
    private(set) var classifiedTitles: [String] = []

    func execute(title: String) async -> ScheduleIconCategory {
        classifiedTitles.append(title)
        return categoriesByTitle[title] ?? .general
    }
}

// MARK: - 세션 조립

@MainActor
@Suite("ActivityViewModel — 일정→세션 조립 (도메인 규칙)")
struct ActivityViewModelSessionMappingTests {

    @Test("세션은 일정 시작 시각 오름차순으로 정렬된다")
    func sessionsSortedByStartTime() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(scheduleId: "S-late", startsAt: fixedNow.addingTimeInterval(7_200)),
            makeSchedule(scheduleId: "S-early", startsAt: fixedNow),
            makeSchedule(scheduleId: "S-mid", startsAt: fixedNow.addingTimeInterval(3_600)),
        ])
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.fetchSessions()

        let ids = try loadedSessions(viewModel).map(\.id.value)
        #expect(ids == ["S-early", "S-mid", "S-late"])
    }

    @Test("일정 제목 분류 결과가 세션 카테고리에 실린다")
    func classifiedCategoryIsAppliedToSession() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([makeSchedule(name: "8주차 데모데이")])
        let classifier = MockClassifyScheduleUseCase()
        classifier.categoriesByTitle = ["8주차 데모데이": .presentation]
        let viewModel = makeViewModel(attendance: attendance, classifier: classifier)

        await viewModel.fetchSessions()

        let session = try #require(try loadedSessions(viewModel).first)
        #expect(session.info.category == .presentation)
    }

    @Test("같은 제목이 여러 일정에 있어도 분류는 한 번만 호출한다")
    func duplicateTitlesAreClassifiedOnce() async {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(scheduleId: "S-1", name: "정기 세션"),
            makeSchedule(scheduleId: "S-2", name: "정기 세션"),
            makeSchedule(scheduleId: "S-3", name: "정기 세션"),
        ])
        let classifier = MockClassifyScheduleUseCase()
        let viewModel = makeViewModel(attendance: attendance, classifier: classifier)

        await viewModel.fetchSessions()

        #expect(classifier.classifiedTitles == ["정기 세션"])
    }

    @Test(
        "서버가 확정한 출석 상태는 초기 출석 기록으로 실린다",
        arguments: [
            (ScheduleAttendanceStatus.present, AttendanceStatus.present),
            (.late, .late),
            (.absent, .absent),
            (.pendingApproval, .pendingApproval),
        ]
    )
    func serverStatusBecomesInitialAttendance(
        scheduleStatus: ScheduleAttendanceStatus,
        expected: AttendanceStatus
    ) async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(attendanceStatus: scheduleStatus),
        ])
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.fetchSessions()

        let session = try #require(try loadedSessions(viewModel).first)
        #expect(session.attendance?.status == expected)
    }

    @Test(
        "출석 상태가 없거나 출석 전이면 초기 출석 기록을 만들지 않는다",
        arguments: [nil, ScheduleAttendanceStatus.beforeAttendance]
    )
    func noAttendanceRecordBeforeAttendance(
        scheduleStatus: ScheduleAttendanceStatus?
    ) async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(attendanceStatus: scheduleStatus),
        ])
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.fetchSessions()

        let session = try #require(try loadedSessions(viewModel).first)
        #expect(session.attendance == nil)
    }

    @Test("출석 기록의 주체는 조회된 사용자 식별자다")
    func attendanceRecordCarriesFetchedUserId() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(attendanceStatus: .present),
        ])
        let userIdUseCase = MockFetchUserIdUseCase()
        userIdUseCase.result = .success(UserID(value: "U-42"))
        let viewModel = makeViewModel(attendance: attendance, userId: userIdUseCase)

        await viewModel.load()

        let session = try #require(try loadedSessions(viewModel).first)
        #expect(session.attendance?.userId == UserID(value: "U-42"))
    }

    @Test("장소가 있는 일정은 좌표를 그대로 옮긴다")
    func locationIsMapped() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(
                location: ScheduleLocation(
                    latitude: 37.582_2,
                    longitude: 127.010_4,
                    locationName: "공학관"
                )
            ),
        ])
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.fetchSessions()

        let session = try #require(try loadedSessions(viewModel).first)
        #expect(session.info.location == Coordinate(latitude: 37.582_2, longitude: 127.010_4))
    }

    @Test("비대면 일정은 좌표가 없어 (0, 0) 으로 둔다")
    func onlineScheduleFallsBackToOrigin() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([makeSchedule(location: nil)])
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.fetchSessions()

        let session = try #require(try loadedSessions(viewModel).first)
        #expect(session.info.location == Coordinate(latitude: 0, longitude: 0))
    }
}

// MARK: - 조회 상태 전이

@MainActor
@Suite("ActivityViewModel — 조회 상태 전이 (도메인 규칙)")
struct ActivityViewModelLoadingStateTests {

    @Test("조회 실패는 failed 로 전이한다")
    func failureTransitionsToFailed() async {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .failure(DomainError.attendanceOutOfRange)
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.fetchSessions()

        #expect(viewModel.sessionsState.error != nil)
    }

    @Test("취소는 실패가 아니라 이전 상태를 복원한다")
    func cancellationRestoresPreviousState() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([makeSchedule()])
        let viewModel = makeViewModel(attendance: attendance)
        await viewModel.fetchSessions()
        let loadedBefore = try loadedSessions(viewModel)

        attendance.availableSchedulesResult = .failure(CancellationError())
        await viewModel.fetchSessions()

        let loadedAfter = try loadedSessions(viewModel)
        #expect(loadedAfter.map(\.id) == loadedBefore.map(\.id))
    }

    @Test("첫 진입에서 취소되면 idle 로 남아 다음 등장 때 다시 조회한다")
    func cancellationOnFirstLoadStaysIdle() async {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .failure(CancellationError())
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.fetchSessions()

        #expect(viewModel.sessionsState.isIdle)
    }

    @Test("조회 진행 중 중복 호출은 무시된다")
    func concurrentFetchIsIgnored() async {
        let attendance = MockRootAttendanceUseCase()
        attendance.gateAvailableSchedules = true
        let viewModel = makeViewModel(attendance: attendance)

        let inFlight = Task { await viewModel.fetchSessions() }
        await drainUntil { attendance.fetchAvailableSchedulesCallCount == 1 }

        await viewModel.fetchSessions()
        #expect(attendance.fetchAvailableSchedulesCallCount == 1)

        attendance.openAvailableSchedulesGate()
        await inFlight.value
    }

    @Test("첫 등장은 전체 조회, 재등장은 배경 갱신을 쓴다")
    func loadPicksFetchThenRefresh() async {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([makeSchedule()])
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.load()
        #expect(attendance.fetchAvailableSchedulesCallCount == 1)

        // 재등장: 로딩 스피너 없이 배경 갱신만 (같은 일정 집합이라 상태 교체 없음)
        await viewModel.load()
        #expect(attendance.fetchAvailableSchedulesCallCount == 2)
        #expect(viewModel.sessionsState.isLoading == false)
    }
}

// MARK: - 배경 갱신

@MainActor
@Suite("ActivityViewModel — 배경 갱신 (도메인 규칙)")
struct ActivityViewModelRefreshTests {

    @Test("일정 집합이 그대로면 세션 배열을 교체하지 않는다")
    func refreshKeepsSessionsWhenMembershipUnchanged() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(scheduleId: "S-1"),
            makeSchedule(scheduleId: "S-2"),
        ])
        let viewModel = makeViewModel(attendance: attendance)
        await viewModel.fetchSessions()
        let before = try loadedSessions(viewModel)

        await viewModel.refreshSessions()

        let after = try loadedSessions(viewModel)
        // 참조 동일성까지 확인 — 새 인스턴스로 교체되면 제출 여부 같은 로컬 상태가 리셋된다.
        #expect(zip(before, after).allSatisfy { $0 === $1 })
    }

    @Test(
        "일정 집합이 달라지면 세션 배열을 교체한다",
        arguments: [
            ["S-1", "S-2", "S-3"],
            ["S-1"],
            ["S-9"],
        ]
    )
    func refreshReplacesSessionsWhenMembershipChanged(freshIds: [String]) async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([
            makeSchedule(scheduleId: "S-1"),
            makeSchedule(scheduleId: "S-2"),
        ])
        let viewModel = makeViewModel(attendance: attendance)
        await viewModel.fetchSessions()

        attendance.availableSchedulesResult = .success(
            freshIds.map { makeSchedule(scheduleId: $0) }
        )
        await viewModel.refreshSessions()

        let after = try loadedSessions(viewModel)
        #expect(Set(after.map(\.id.value)) == Set(freshIds))
    }

    @Test("배경 갱신 실패는 기존 목록을 유지한다")
    func refreshFailureKeepsCurrentSessions() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([makeSchedule(scheduleId: "S-1")])
        let viewModel = makeViewModel(attendance: attendance)
        await viewModel.fetchSessions()

        attendance.availableSchedulesResult = .failure(SampleError())
        await viewModel.refreshSessions()

        #expect(try loadedSessions(viewModel).map(\.id.value) == ["S-1"])
    }

    @Test("아직 로드된 목록이 없으면 배경 갱신 대신 전체 조회로 대체한다")
    func refreshFallsBackToFetchWhenNotLoaded() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([makeSchedule(scheduleId: "S-1")])
        let viewModel = makeViewModel(attendance: attendance)

        await viewModel.refreshSessions()

        #expect(try loadedSessions(viewModel).map(\.id.value) == ["S-1"])
    }
}

// MARK: - 사용자 식별자

@MainActor
@Suite("ActivityViewModel — 사용자 식별자 (도메인 규칙)")
struct ActivityViewModelUserIdTests {

    @Test("조회에 성공하면 userId 를 채운다")
    func userIdIsStoredOnSuccess() async {
        let userIdUseCase = MockFetchUserIdUseCase()
        userIdUseCase.result = .success(UserID(value: "U-7"))
        let viewModel = makeViewModel(userId: userIdUseCase)

        await viewModel.fetchUserId()

        #expect(viewModel.userId == UserID(value: "U-7"))
    }

    @Test("조회에 실패해도 세션 조회를 막지 않는다")
    func userIdFailureDoesNotBlockSessions() async throws {
        let attendance = MockRootAttendanceUseCase()
        attendance.availableSchedulesResult = .success([makeSchedule(scheduleId: "S-1")])
        let userIdUseCase = MockFetchUserIdUseCase()
        userIdUseCase.result = .failure(AuthError.notLoggedIn)
        let viewModel = makeViewModel(attendance: attendance, userId: userIdUseCase)

        await viewModel.load()

        #expect(viewModel.userId == nil)
        #expect(try loadedSessions(viewModel).map(\.id.value) == ["S-1"])
    }

    @Test("이미 식별자가 있으면 재등장 시 다시 조회하지 않는다")
    func userIdIsFetchedOnlyOnce() async {
        let userIdUseCase = MockFetchUserIdUseCase()
        let viewModel = makeViewModel(userId: userIdUseCase)

        await viewModel.load()
        await viewModel.load()

        #expect(userIdUseCase.callCount == 1)
    }
}

#endif
