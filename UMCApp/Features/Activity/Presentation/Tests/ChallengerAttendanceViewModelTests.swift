//
//  ChallengerAttendanceViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 6/12/26.
//

import Foundation
import Testing
import ActivityDomain
import HomeDomain
import UMCFoundation
@testable import ActivityPresentation

// MARK: - Helpers

/// 결정론적 기준 시각 (epoch 100_000) — wall-clock 비의존
private let fixedNow = Date(timeIntervalSince1970: 100_000)

private func makeSessionInfo(
    sessionId: String = "S-1",
    startTime: Date = fixedNow,
    endTime: Date = fixedNow.addingTimeInterval(3_600)
) -> SessionInfo {
    SessionInfo(
        sessionId: SessionID(value: sessionId),
        iconName: "calendar.badge",
        title: "1주차 OT",
        week: 1,
        startTime: startTime,
        endTime: endTime,
        location: Coordinate(latitude: 37.5, longitude: 127.0)
    )
}

@MainActor
private func makeSession(
    sessionId: String = "S-1",
    initialAttendance: Attendance? = nil
) -> Session {
    Session(
        info: makeSessionInfo(sessionId: sessionId),
        initialAttendance: initialAttendance
    )
}

private func makeAttendance(
    status: AttendanceStatus = .present,
    type: AttendanceType = .gps,
    reason: String? = nil
) -> Attendance {
    Attendance(
        sessionId: SessionID(value: "S-1"),
        userId: UserID(value: "U-1"),
        type: type,
        status: status,
        reason: reason
    )
}

/// 정책 기준: checkIn = fixedNow-600, onTimeEnd = fixedNow+600, lateEnd = fixedNow+1200
private func makePolicy(
    checkInStartAt: Date = fixedNow.addingTimeInterval(-600),
    onTimeEndAt: Date = fixedNow.addingTimeInterval(600),
    lateEndAt: Date = fixedNow.addingTimeInterval(1_200)
) -> ScheduleAttendancePolicy {
    ScheduleAttendancePolicy(
        checkInStartAt: checkInStartAt,
        onTimeEndAt: onTimeEndAt,
        lateEndAt: lateEndAt
    )
}

/// 일정 픽스처.
///
/// `attendanceStatus` 는 폴링 동기화 테스트에서만 의미가 있어 기본값은 `nil`(서버 미제공)이다.
private func makeScheduleDetail(
    scheduleId: String = "S-1",
    policy: ScheduleAttendancePolicy? = nil,
    attendanceStatus: ScheduleAttendanceStatus? = nil,
    startsAt: Date = fixedNow
) -> ScheduleDetailData {
    ScheduleDetailData(
        scheduleId: scheduleId,
        name: "1주차 OT",
        description: "",
        tags: [],
        startsAt: startsAt,
        endsAt: startsAt.addingTimeInterval(3_600),
        isParticipant: true,
        attendancePolicy: policy,
        attendanceStatus: attendanceStatus
    )
}

@MainActor
private func makeViewModel(
    useCase: MockChallengerAttendanceUseCase,
    errorHandler: ErrorHandler = ErrorHandler()
) -> ChallengerAttendanceViewModel {
    ChallengerAttendanceViewModel(
        errorHandler: errorHandler,
        challengerAttendanceUseCase: useCase
    )
}

/// 서버 정책이 실린 일정 목록을 실제 조회 경로로 적재한다.
///
/// 정책은 별도 캐시가 아니라 `availableSchedules` 페이로드에서 읽으므로, 시간대·안내 문구
/// 테스트도 조회를 한 번 태워 상태를 만든다.
@MainActor
private func seedSchedules(
    _ viewModel: ChallengerAttendanceViewModel,
    useCase: MockChallengerAttendanceUseCase,
    schedules: [ScheduleDetailData]
) async {
    useCase.availableSchedulesResult = .success(schedules)
    await viewModel.fetchAvailableSchedules()
}

private struct DummyError: Error {}

// MARK: - Mocks

#if DEBUG

private final class MockChallengerAttendanceUseCase: @unchecked Sendable,
    ChallengerAttendanceUseCaseProtocol {

    // MARK: 상태 제어

    var isInsideGeofence: Bool = true
    var isLocationAuthorized: Bool = true

    var requestGPSAttendanceResult: Result<Attendance, Error> = .success(makeAttendance())
    var submitLateReasonResult: Result<Attendance, Error> = .success(
        makeAttendance(status: .pendingApproval, type: .reason, reason: "사유")
    )
    var submitAbsentReasonResult: Result<Attendance, Error> = .success(
        makeAttendance(status: .pendingApproval, type: .reason, reason: "사유")
    )

    /// `isWithinAttendanceTime` 폴백 판정이 반환할 시간대
    var timeWindowToReturn: AttendanceTimeWindow = .onTime

    var availableSchedulesResult: Result<[ScheduleDetailData], Error> = .success([])
    var myHistoryResult: Result<[ScheduleDetailData], Error> = .success([])

    /// `true` 면 일정 조회가 ``openAvailableSchedulesGate()`` 전까지 반환하지 않는다.
    ///
    /// 재진입 가드처럼 "요청이 진행 중인 순간" 을 관찰해야 하는 테스트에서 쓴다.
    /// 대기를 `CheckedContinuation` 등록이 아니라 플래그 폴링으로 구현한 이유: 조회는
    /// MainActor 밖(비격리 mock)에서 재개되므로, 등록 시점과 해제 시점이 다른 실행자에
    /// 걸치면 아직 등록되지 않은 continuation 을 깨우려다 영영 멈춘다.
    var gateAvailableSchedules: Bool = false

    // MARK: 호출 기록

    private(set) var requestGPSAttendanceCalls: [(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: String
    )] = []

    private(set) var submitLateReasonCalls: [(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    )] = []

    private(set) var submitAbsentReasonCalls: [(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    )] = []

    private(set) var isWithinAttendanceTimeCallCount: Int = 0
    private(set) var stopGeofenceMonitoringCallCount: Int = 0
    private(set) var fetchAvailableSchedulesCallCount: Int = 0
    private(set) var fetchMyHistoryCallCount: Int = 0

    // MARK: Protocol

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

    func fetchMyHistory(now: Date) async throws -> [ScheduleDetailData] {
        fetchMyHistoryCallCount += 1
        return try myHistoryResult.get()
    }

    func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: String
    ) async throws -> Attendance {
        requestGPSAttendanceCalls.append((sessionId, userId, scheduleId))
        return try requestGPSAttendanceResult.get()
    }

    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        submitLateReasonCalls.append((sessionId, userId, reason, scheduleId))
        return try submitLateReasonResult.get()
    }

    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        submitAbsentReasonCalls.append((sessionId, userId, reason, scheduleId))
        return try submitAbsentReasonResult.get()
    }

    func isWithinAttendanceTime(info: SessionInfo, now: Date) -> AttendanceTimeWindow {
        isWithinAttendanceTimeCallCount += 1
        return timeWindowToReturn
    }

    func getAddressToCurrentLocation() async throws -> Address {
        Address(
            fullAddress: "서울특별시 성북구 삼선동",
            city: "서울특별시",
            district: "성북구"
        )
    }

    func stopGeofenceMonitoring() async {
        stopGeofenceMonitoringCallCount += 1
    }
}

#endif

// MARK: - GPS 출석 요청

// Suite 전체 @MainActor — SUT(ViewModel)와 Session 이 @MainActor 격리이므로 필요.
@MainActor
@Suite("ChallengerAttendanceViewModel — GPS 출석 요청 (도메인 규칙)")
struct ChallengerAttendanceViewModelGPSTests {

    @Test(
        "정시가 아닌 시간대 → 출석 요청 미전송 + 상태 불변",
        arguments: [
            AttendanceTimeWindow.tooEarly,
            AttendanceTimeWindow.lateWindow,
            AttendanceTimeWindow.expired,
        ]
    )
    func attendanceRequestBlockedOutsideOnTime(window: AttendanceTimeWindow) async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = window
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        await viewModel.attendanceButtonTapped(
            userId: UserID(value: "U-1"),
            session: session,
            scheduleId: "42"
        )

        #expect(useCase.requestGPSAttendanceCalls.isEmpty)
        #expect(session.attendanceLoadable == .idle)
    }

    @Test("정시 + 성공 → loaded 전이 + 제출 완료 + scheduleId String 전달")
    func attendanceRequestSucceeds() async throws {
        let expected = makeAttendance(status: .present)
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .onTime
        useCase.requestGPSAttendanceResult = .success(expected)
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        await viewModel.attendanceButtonTapped(
            userId: UserID(value: "U-3"),
            session: session,
            scheduleId: "42"
        )

        let call = try #require(useCase.requestGPSAttendanceCalls.first)
        #expect(call.scheduleId == "42")
        #expect(call.userId == UserID(value: "U-3"))
        #expect(call.sessionId == session.info.sessionId)
        #expect(session.attendanceLoadable == .loaded(expected))
        #expect(session.hasSubmitted == true)
    }

    @Test("정시 + DomainError → failed(.domain) 인라인 상태 (Alert 미발생)")
    func attendanceRequestFailsWithDomainError() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.requestGPSAttendanceResult = .failure(DomainError.attendanceOutOfRange)
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase: useCase, errorHandler: errorHandler)
        let session = makeSession()

        await viewModel.attendanceButtonTapped(
            userId: UserID(value: "U-1"),
            session: session,
            scheduleId: "42"
        )

        #expect(session.attendanceLoadable == .failed(.domain(.attendanceOutOfRange)))
        #expect(session.hasSubmitted == false)
        #expect(errorHandler.currentError == nil)
    }

    @Test("정시 + 기타 에러 + 기존 출석 없음 → idle 복구 + ErrorHandler Alert")
    func attendanceRequestRecoversToIdleOnUnknownError() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.requestGPSAttendanceResult = .failure(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase: useCase, errorHandler: errorHandler)
        let session = makeSession()

        await viewModel.attendanceButtonTapped(
            userId: UserID(value: "U-1"),
            session: session,
            scheduleId: "42"
        )

        #expect(session.attendanceLoadable == .idle)
        #expect(errorHandler.currentError != nil)
    }

    @Test("정시 + 기타 에러 + 기존 출석 있음 → 이전 출석 상태로 복구")
    func attendanceRequestRestoresPreviousAttendanceOnUnknownError() async {
        let previous = makeAttendance(status: .beforeAttendance)
        let useCase = MockChallengerAttendanceUseCase()
        useCase.requestGPSAttendanceResult = .failure(DummyError())
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession(initialAttendance: previous)

        await viewModel.attendanceButtonTapped(
            userId: UserID(value: "U-1"),
            session: session,
            scheduleId: "42"
        )

        #expect(session.attendanceLoadable == .loaded(previous))
    }
}

// MARK: - 사유 제출 라우팅

@MainActor
@Suite("ChallengerAttendanceViewModel — 사유 제출 라우팅 (도메인 규칙)")
struct ChallengerAttendanceViewModelExcuseTests {

    @Test(
        "마감 전 시간대(시작 전/정시/지각) → 지각 사유로 제출",
        arguments: [
            AttendanceTimeWindow.tooEarly,
            AttendanceTimeWindow.onTime,
            AttendanceTimeWindow.lateWindow,
        ]
    )
    func excuseRoutesToLateReasonBeforeExpiry(window: AttendanceTimeWindow) async throws {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = window
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        await viewModel.submitAttendanceReason(
            userId: UserID(value: "U-1"),
            session: session,
            reason: "지각 사유",
            scheduleId: "7"
        )

        let call = try #require(useCase.submitLateReasonCalls.first)
        #expect(call.reason == "지각 사유")
        #expect(call.scheduleId == "7")
        #expect(useCase.submitAbsentReasonCalls.isEmpty)
        #expect(session.hasSubmitted == true)
    }

    @Test("마감 후(expired) → 결석 사유로 제출")
    func excuseRoutesToAbsentReasonAfterExpiry() async throws {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .expired
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        await viewModel.submitAttendanceReason(
            userId: UserID(value: "U-1"),
            session: session,
            reason: "결석 사유",
            scheduleId: "7"
        )

        let call = try #require(useCase.submitAbsentReasonCalls.first)
        #expect(call.reason == "결석 사유")
        #expect(useCase.submitLateReasonCalls.isEmpty)
    }

    @Test("사유 제출 성공 → loaded 전이 + 제출 완료")
    func excuseSubmissionSucceeds() async {
        let expected = makeAttendance(status: .pendingApproval, type: .reason, reason: "사유")
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .lateWindow
        useCase.submitLateReasonResult = .success(expected)
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        await viewModel.submitAttendanceReason(
            userId: UserID(value: "U-1"),
            session: session,
            reason: "사유",
            scheduleId: "7"
        )

        #expect(session.attendanceLoadable == .loaded(expected))
        #expect(session.hasSubmitted == true)
    }

    @Test("빈 사유 거부(DomainError) → failed(.domain) 인라인 상태")
    func excuseSubmissionFailsWithDomainError() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .lateWindow
        useCase.submitLateReasonResult = .failure(DomainError.attendanceReasonRequired)
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        await viewModel.submitAttendanceReason(
            userId: UserID(value: "U-1"),
            session: session,
            reason: "",
            scheduleId: "7"
        )

        #expect(session.attendanceLoadable == .failed(.domain(.attendanceReasonRequired)))
        #expect(session.hasSubmitted == false)
    }

    @Test("기타 에러 → 상태 복구 + ErrorHandler Alert")
    func excuseSubmissionRecoversOnUnknownError() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .lateWindow
        useCase.submitLateReasonResult = .failure(DummyError())
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase: useCase, errorHandler: errorHandler)
        let session = makeSession()

        await viewModel.submitAttendanceReason(
            userId: UserID(value: "U-1"),
            session: session,
            reason: "사유",
            scheduleId: "7"
        )

        #expect(session.attendanceLoadable == .idle)
        #expect(errorHandler.currentError != nil)
    }

    @Test("기타 에러 + 기존 출석 있음 → 이전 출석 상태로 복구")
    func excuseSubmissionRestoresPreviousAttendanceOnUnknownError() async {
        let previous = makeAttendance(status: .beforeAttendance)
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .lateWindow
        useCase.submitLateReasonResult = .failure(DummyError())
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession(initialAttendance: previous)

        await viewModel.submitAttendanceReason(
            userId: UserID(value: "U-1"),
            session: session,
            reason: "사유",
            scheduleId: "7"
        )

        #expect(session.attendanceLoadable == .loaded(previous))
    }
}

// MARK: - 시간대 판정

@MainActor
@Suite("ChallengerAttendanceViewModel — 시간대 판정 (도메인 규칙)")
struct ChallengerAttendanceViewModelTimeWindowTests {

    @Test("정책 미조회 → UseCase 폴백 판정 사용")
    func timeWindowFallsBackToUseCaseWithoutPolicy() {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .lateWindow
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        let window = viewModel.timeWindow(for: session, now: fixedNow)

        #expect(window == .lateWindow)
        #expect(useCase.isWithinAttendanceTimeCallCount == 1)
    }

    @Test("정책 조회 후 → 서버 정책 우선 판정 (폴백 미사용)")
    func timeWindowPrefersServerPolicy() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .expired  // 폴백이 쓰였다면 expired 가 나와야 함
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [makeScheduleDetail(policy: makePolicy())]
        )

        let window = viewModel.timeWindow(for: session, now: fixedNow)

        #expect(window == .onTime)
        #expect(useCase.isWithinAttendanceTimeCallCount == 0)
    }

    @Test(
        "정책 시각 경계값 판정",
        arguments: [
            (offset: TimeInterval(-601), expected: AttendanceTimeWindow.tooEarly),
            (offset: TimeInterval(-600), expected: AttendanceTimeWindow.onTime),
            (offset: TimeInterval(600), expected: AttendanceTimeWindow.onTime),
            (offset: TimeInterval(601), expected: AttendanceTimeWindow.lateWindow),
            (offset: TimeInterval(1_200), expected: AttendanceTimeWindow.lateWindow),
            (offset: TimeInterval(1_201), expected: AttendanceTimeWindow.expired),
        ]
    )
    func timeWindowPolicyBoundaries(
        offset: TimeInterval,
        expected: AttendanceTimeWindow
    ) async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        // 정책: checkIn = fixedNow-600, onTimeEnd = fixedNow+600, lateEnd = fixedNow+1200
        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [makeScheduleDetail(policy: makePolicy())]
        )

        let window = viewModel.timeWindow(
            for: session,
            now: fixedNow.addingTimeInterval(offset)
        )

        #expect(window == expected)
    }

    // MARK: - 정책 조회 (표시용)

    @Test("주입한 정책은 판정과 같은 캐시에서 조회된다")
    func attendancePolicyReadsInjectedCache() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())
        let session = makeSession()
        let policy = makePolicy()
        viewModel.updateSchedulePolicies([session.info.sessionId: policy])

        #expect(viewModel.attendancePolicy(for: session.info.sessionId) == policy)
    }

    @Test("정책 미조회 세션은 nil 을 반환한다")
    func attendancePolicyReturnsNilWhenNotFetched() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())
        let session = makeSession()

        #expect(viewModel.attendancePolicy(for: session.info.sessionId) == nil)
    }

    // MARK: - 서버 일정 ID 조회 (제출 경로)

    @Test("주입한 서버 일정 ID가 조회된다")
    func scheduleIdReadsInjectedCache() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())
        let session = makeSession()
        viewModel.updateScheduleIds([session.info.sessionId: "SCH-1"])

        #expect(viewModel.scheduleId(for: session.info.sessionId) == "SCH-1")
    }

    /// 회귀 박제 — 일정 ID가 없으면 출석·사유 제출이 서버에 도달할 수 없다.
    /// 화면은 이 nil 을 근거로 액션 버튼을 비활성화해, 사용자가 작성한 사유가
    /// 조용히 버려지지 않게 한다.
    @Test("일정 ID 미조회 세션은 nil 을 반환한다")
    func scheduleIdReturnsNilWhenNotFetched() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())
        let session = makeSession()

        #expect(viewModel.scheduleId(for: session.info.sessionId) == nil)
    }
}

// MARK: - 출석 안내 문구

@MainActor
@Suite("ChallengerAttendanceViewModel — 출석 안내 문구 (도메인 규칙)")
struct ChallengerAttendanceViewModelGuidanceTests {

    @Test("출석 전 상태가 아니면 안내 문구 없음")
    func guidanceHiddenWhenAlreadyDecided() {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession(initialAttendance: makeAttendance(status: .present))

        #expect(viewModel.attendanceGuidanceText(for: session, at: fixedNow) == nil)
    }

    @Test(
        "정책 미조회 — 시간대별 폴백 문구",
        arguments: [
            (window: AttendanceTimeWindow.tooEarly, expected: "아직 출석 시간 전이에요"),
            (window: AttendanceTimeWindow.onTime, expected: "지금 출석하면 정시로 인정돼요"),
            (window: AttendanceTimeWindow.lateWindow, expected: "지각 시간대예요 — 사유를 제출해 주세요"),
        ]
    )
    func guidanceFallbackTextWithoutPolicy(
        window: AttendanceTimeWindow,
        expected: String
    ) {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = window
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        #expect(viewModel.attendanceGuidanceText(for: session, at: fixedNow) == expected)
    }

    @Test("마감(expired) 시간대 → 안내 문구 없음 (버튼 문구가 대신함)")
    func guidanceHiddenWhenExpired() {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .expired
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()

        #expect(viewModel.attendanceGuidanceText(for: session, at: fixedNow) == nil)
    }

    @Test("정책 조회 + 정시 → 마감 시각과 남은 시간 표시")
    func guidanceShowsOnTimeDeadlineWithPolicy() async throws {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [
                makeScheduleDetail(
                    policy: makePolicy(
                        onTimeEndAt: fixedNow.addingTimeInterval(420)  // 7분 뒤 마감
                    )
                )
            ]
        )

        let text = try #require(viewModel.attendanceGuidanceText(for: session, at: fixedNow))

        #expect(text.hasPrefix("출석 인정 마감 "))
        #expect(text.hasSuffix("· 7분 남음"))
    }

    @Test("정책 조회 + 지각 → 지각 마감 시각과 남은 시간 표시")
    func guidanceShowsLateDeadlineWithPolicy() async throws {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [
                makeScheduleDetail(
                    policy: makePolicy(
                        onTimeEndAt: fixedNow.addingTimeInterval(-60),  // 정시 마감 지남
                        lateEndAt: fixedNow.addingTimeInterval(720)     // 지각 마감 12분 뒤
                    )
                )
            ]
        )

        let text = try #require(viewModel.attendanceGuidanceText(for: session, at: fixedNow))

        #expect(text.hasPrefix("지각 인정 마감 "))
        #expect(text.hasSuffix("· 12분 남음"))
    }

    @Test("정책 조회 + 출석 시작 전 → 시작 시각 안내")
    func guidanceShowsCheckInStartWithPolicy() async throws {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [
                makeScheduleDetail(
                    policy: makePolicy(
                        checkInStartAt: fixedNow.addingTimeInterval(600)  // 10분 뒤 시작
                    )
                )
            ]
        )

        let text = try #require(viewModel.attendanceGuidanceText(for: session, at: fixedNow))

        #expect(text.hasSuffix("부터 출석할 수 있어요"))
    }

    @Test(
        "남은 시간 1시간 이상 → 시간/분 조합 표기",
        arguments: [
            (secondsLeft: TimeInterval(3_600), suffix: "· 1시간 남음"),
            (secondsLeft: TimeInterval(4_320), suffix: "· 1시간 12분 남음"),
        ]
    )
    func guidanceFormatsHourScaleRemaining(
        secondsLeft: TimeInterval,
        suffix: String
    ) async throws {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [
                makeScheduleDetail(
                    policy: makePolicy(
                        onTimeEndAt: fixedNow.addingTimeInterval(secondsLeft)
                    )
                )
            ]
        )

        let text = try #require(viewModel.attendanceGuidanceText(for: session, at: fixedNow))

        #expect(text.hasSuffix(suffix))
    }
}

// MARK: - 사유 보조 링크 노출

@MainActor
@Suite("ChallengerAttendanceViewModel — 사유 보조 링크 노출 (도메인 규칙)")
struct ChallengerAttendanceViewModelReasonButtonTests {

    @Test(
        "정시/시작 전 + 미제출 세션 → 보조 링크 노출",
        arguments: [AttendanceTimeWindow.tooEarly, AttendanceTimeWindow.onTime]
    )
    func reasonButtonVisibleBeforeLateWindow(window: AttendanceTimeWindow) {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = window
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.shouldShowReasonButton(for: makeSession()) == true)
    }

    @Test(
        "지각/마감 시간대 → 보조 링크 숨김 (지각은 기본 버튼으로 승격)",
        arguments: [AttendanceTimeWindow.lateWindow, AttendanceTimeWindow.expired]
    )
    func reasonButtonHiddenFromLateWindow(window: AttendanceTimeWindow) {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = window
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.shouldShowReasonButton(for: makeSession()) == false)
    }

    @Test("이미 제출한 세션 → 보조 링크 숨김")
    func reasonButtonHiddenAfterSubmission() {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .onTime
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        session.markSubmitted()

        #expect(viewModel.shouldShowReasonButton(for: session) == false)
    }
}

// MARK: - 버튼/가용성 위임

@MainActor
@Suite("ChallengerAttendanceViewModel — 버튼/가용성 위임 (도메인 규칙)")
struct ChallengerAttendanceViewModelDelegationTests {

    @Test("정시 + 권한 + 지오펜스 내부 → '현 위치로 출석체크'")
    func buttonTitleAllReady() {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .onTime
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.buttonTitle(for: makeSession()) == "현 위치로 출석체크")
    }

    @Test("위치 권한 없음 → '위치 권한 필요'")
    func buttonTitleNeedsLocationPermission() {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .onTime
        useCase.isLocationAuthorized = false
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.buttonTitle(for: makeSession()) == "위치 권한 필요")
    }

    @Test("정시 + 권한 + 지오펜스 내부 → 출석 요청 가능")
    func attendanceAvailableWhenAllReady() {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .onTime
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.isAttendanceAvailable(for: makeSession()) == true)
    }

    @Test("지오펜스 밖 → 출석 요청 불가")
    func attendanceUnavailableOutsideGeofence() {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.timeWindowToReturn = .onTime
        useCase.isInsideGeofence = false
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.isAttendanceAvailable(for: makeSession()) == false)
    }

    @Test("미제출 세션 → 사유 제출 가능 위임")
    func reasonSubmittableDelegatesToSession() {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.isReasonSubmittable(for: makeSession()) == true)
    }

    @Test("geofenceCleanup → 지오펜스 모니터링 중지 위임")
    func geofenceCleanupDelegates() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.geofenceCleanup()

        #expect(useCase.stopGeofenceMonitoringCallCount == 1)
    }
}

// MARK: - 일정 목록/이력 로딩

@MainActor
@Suite("ChallengerAttendanceViewModel — 일정 목록/이력 로딩 (도메인 규칙)")
struct ChallengerAttendanceViewModelLoadingTests {

    @Test("첫 마운트 — 빈 배열 시드 후 배경 갱신으로 페이로드를 채운다")
    func loadOnAppearSeedsThenRefreshes() async throws {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.availableSchedulesResult = .success([makeScheduleDetail()])
        useCase.myHistoryResult = .success([makeScheduleDetail(scheduleId: "H-1")])
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.loadOnAppear()

        #expect(viewModel.availableSchedules.value?.map(\.scheduleId) == ["S-1"])
        #expect(viewModel.myHistory.value?.map(\.scheduleId) == ["H-1"])
    }

    @Test("첫 마운트 — 이력은 로딩 UI 를 태우는 fetch 경로로 조회한다")
    func loadOnAppearUsesFetchForFirstHistoryLoad() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.loadOnAppear()

        #expect(useCase.fetchMyHistoryCallCount == 1)
        #expect(viewModel.myHistory.value != nil)
    }

    @Test("재등장 — 두 목록 모두 배경 갱신만 하고 로딩 상태로 되돌리지 않는다")
    func loadOnAppearRefreshesOnReappear() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.loadOnAppear()

        useCase.availableSchedulesResult = .success([makeScheduleDetail(scheduleId: "S-2")])
        useCase.myHistoryResult = .success([makeScheduleDetail(scheduleId: "H-2")])
        await viewModel.loadOnAppear()

        #expect(viewModel.availableSchedules.value?.map(\.scheduleId) == ["S-2"])
        #expect(viewModel.myHistory.value?.map(\.scheduleId) == ["H-2"])
        #expect(useCase.fetchAvailableSchedulesCallCount == 2)
        #expect(useCase.fetchMyHistoryCallCount == 2)
    }

    @Test("fetch 실패 → .failed 로 재시도 UI 를 노출한다")
    func fetchAvailableSchedulesFailsToFailedState() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.availableSchedulesResult = .failure(DummyError())
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchAvailableSchedules()

        #expect(viewModel.availableSchedules.error != nil)
    }

    @Test("이력 fetch 실패 → .failed 로 재시도 UI 를 노출한다")
    func fetchMyHistoryFailsToFailedState() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.myHistoryResult = .failure(DummyError())
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMyHistory()

        #expect(viewModel.myHistory.error != nil)
    }

    @Test("배경 갱신 실패 → 기존 목록을 유지하고 .failed 로 전이하지 않는다")
    func refreshFailureKeepsPreviousSchedules() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.availableSchedulesResult = .success([makeScheduleDetail()])
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchAvailableSchedules()

        useCase.availableSchedulesResult = .failure(DummyError())
        await viewModel.refreshAvailableSchedules()

        #expect(viewModel.availableSchedules.value?.map(\.scheduleId) == ["S-1"])
        #expect(viewModel.availableSchedules.error == nil)
    }
}

// MARK: - 조회 취소 처리

@MainActor
@Suite("ChallengerAttendanceViewModel — 조회 취소 처리 (도메인 규칙)")
struct ChallengerAttendanceViewModelCancellationTests {

    @Test("첫 조회 취소 → .idle 로 남아 다음 등장 때 다시 조회한다")
    func cancelledFirstFetchStaysIdle() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.availableSchedulesResult = .failure(CancellationError())
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchAvailableSchedules()

        #expect(viewModel.availableSchedules.isIdle)
        #expect(viewModel.availableSchedules.error == nil)
    }

    @Test("적재 후 조회 취소 → 이전 목록으로 되돌리고 에러 카드를 띄우지 않는다")
    func cancelledRefetchRestoresPreviousSchedules() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.availableSchedulesResult = .success([makeScheduleDetail()])
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchAvailableSchedules()

        useCase.availableSchedulesResult = .failure(CancellationError())
        await viewModel.fetchAvailableSchedules()

        #expect(viewModel.availableSchedules.value?.map(\.scheduleId) == ["S-1"])
        #expect(viewModel.availableSchedules.error == nil)
    }

    @Test("이력 조회 취소 → .failed 로 전이하지 않는다")
    func cancelledHistoryFetchDoesNotFail() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.myHistoryResult = .failure(CancellationError())
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchMyHistory()

        #expect(viewModel.myHistory.error == nil)
        #expect(viewModel.myHistory.isIdle)
    }

    @Test("조회 진행 중 재호출 → 중복 요청을 보내지 않는다")
    func concurrentFetchIsGuarded() async {
        let useCase = MockChallengerAttendanceUseCase()
        useCase.gateAvailableSchedules = true
        let viewModel = makeViewModel(useCase: useCase)

        let first = Task { await viewModel.fetchAvailableSchedules() }
        await drainUntil { useCase.fetchAvailableSchedulesCallCount == 1 }

        // 진행 중인 요청이 아직 안 끝난 시점의 재호출은 무시돼야 한다.
        await viewModel.fetchAvailableSchedules()
        #expect(useCase.fetchAvailableSchedulesCallCount == 1)

        useCase.openAvailableSchedulesGate()
        await first.value
        #expect(viewModel.availableSchedules.value != nil)
    }
}

// MARK: - 일정 매핑 / 폴링 동기화

@MainActor
@Suite("ChallengerAttendanceViewModel — 일정 매핑·폴링 동기화 (도메인 규칙)")
struct ChallengerAttendanceViewModelSyncTests {

    @Test("조회 전 → 일정 매핑이 nil")
    func scheduleLookupNilBeforeLoad() {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        #expect(viewModel.schedule(for: SessionID(value: "S-1")) == nil)
        #expect(viewModel.scheduleId(for: SessionID(value: "S-1")) == nil)
    }

    @Test("조회 후 → SessionID 와 같은 scheduleId 를 돌려준다")
    func scheduleLookupResolvesLoadedPayload() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [makeScheduleDetail(scheduleId: "S-1")]
        )

        #expect(viewModel.scheduleId(for: SessionID(value: "S-1")) == "S-1")
        #expect(viewModel.scheduleId(for: SessionID(value: "S-9")) == nil)
    }

    @Test("폴링 동기화 — 서버 출석 상태를 Session 에 전파한다")
    func syncPropagatesServerStatusToSession() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        viewModel.configurePollingSessions([session], userId: UserID(value: "U-1"))

        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [makeScheduleDetail(attendanceStatus: .present)]
        )

        #expect(session.attendanceStatus == .present)
    }

    @Test("폴링 동기화 — 서버가 상태를 안 주면 로컬 상태를 덮어쓰지 않는다")
    func syncKeepsSessionWhenServerStatusMissing() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession(initialAttendance: makeAttendance(status: .late))
        viewModel.configurePollingSessions([session], userId: UserID(value: "U-1"))

        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [makeScheduleDetail(attendanceStatus: nil)]
        )

        #expect(session.attendanceStatus == .late)
    }

    @Test("폴링 동기화 — 목록에 없는 세션은 건드리지 않는다")
    func syncIgnoresUnmatchedSession() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession(sessionId: "S-1")
        viewModel.configurePollingSessions([session], userId: UserID(value: "U-1"))

        await seedSchedules(
            viewModel,
            useCase: useCase,
            schedules: [makeScheduleDetail(scheduleId: "S-9", attendanceStatus: .absent)]
        )

        #expect(session.attendanceStatus == .beforeAttendance)
    }
}
