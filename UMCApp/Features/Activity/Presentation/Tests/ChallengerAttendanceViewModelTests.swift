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

// Mock 과 이를 사용하는 헬퍼·스위트 전체를 하나의 가드 안에 둔다.
// (`makeViewModel` 은 Mock 을 파라미터 타입으로 직접 참조한다)
#if DEBUG

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

private struct DummyError: Error {}

// MARK: - Mocks

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

    /// 일정 조회 호출 기록 — SUT 가 조회 경로를 되살리지 않았는지 확인하는 용도.
    private(set) var fetchAvailableSchedulesCallCount: Int = 0
    private(set) var fetchMyHistoryCallCount: Int = 0

    // MARK: Protocol

    func fetchAvailableSchedules(now: Date) async throws -> [ScheduleDetailData] {
        fetchAvailableSchedulesCallCount += 1
        return []
    }

    func fetchMyHistory(now: Date) async throws -> [ScheduleDetailData] {
        fetchMyHistoryCallCount += 1
        return []
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
        viewModel.apply(schedules: [makeScheduleDetail(policy: makePolicy())])

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
        viewModel.apply(schedules: [makeScheduleDetail(policy: makePolicy())])

        let window = viewModel.timeWindow(
            for: session,
            now: fixedNow.addingTimeInterval(offset)
        )

        #expect(window == expected)
    }

    // MARK: - 정책 조회 (표시용)

    @Test("조회된 정책은 판정과 같은 페이로드에서 읽힌다")
    func attendancePolicyReadsLoadedPayload() async {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        let policy = makePolicy()
        viewModel.apply(schedules: [makeScheduleDetail(policy: policy)])

        #expect(viewModel.attendancePolicy(for: session.info.sessionId) == policy)
    }

    @Test("정책 미조회 세션은 nil 을 반환한다")
    func attendancePolicyReturnsNilWhenNotFetched() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())
        let session = makeSession()

        #expect(viewModel.attendancePolicy(for: session.info.sessionId) == nil)
    }

    // MARK: - 서버 일정 ID 조회 (제출 경로)

    @Test("전달된 일정의 서버 ID가 반환된다")
    func scheduleIdReadsAppliedPayload() {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        viewModel.apply(schedules: [makeScheduleDetail(scheduleId: "S-1")])

        #expect(viewModel.scheduleId(for: session.info.sessionId) == "S-1")
    }

    /// 회귀 박제 — 일정 ID가 없으면 출석·사유 제출이 서버에 도달할 수 없다.
    /// 화면은 이 nil 을 근거로 액션 버튼을 비활성화해, 사용자가 작성한 사유가
    /// 조용히 버려지지 않게 한다.
    @Test("일정 페이로드에 없는 세션은 nil 을 반환한다")
    func scheduleIdReturnsNilWhenNotApplied() {
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
        viewModel.apply(schedules: [
            makeScheduleDetail(
                policy: makePolicy(
                    onTimeEndAt: fixedNow.addingTimeInterval(420)  // 7분 뒤 마감
                )
            )
        ])

        let text = try #require(viewModel.attendanceGuidanceText(for: session, at: fixedNow))

        #expect(text.hasPrefix("출석 인정 마감 "))
        #expect(text.hasSuffix("· 7분 남음"))
    }

    @Test("정책 조회 + 지각 → 지각 마감 시각과 남은 시간 표시")
    func guidanceShowsLateDeadlineWithPolicy() async throws {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        viewModel.apply(schedules: [
            makeScheduleDetail(
                policy: makePolicy(
                    onTimeEndAt: fixedNow.addingTimeInterval(-60),  // 정시 마감 지남
                    lateEndAt: fixedNow.addingTimeInterval(720)     // 지각 마감 12분 뒤
                )
            )
        ])

        let text = try #require(viewModel.attendanceGuidanceText(for: session, at: fixedNow))

        #expect(text.hasPrefix("지각 인정 마감 "))
        #expect(text.hasSuffix("· 12분 남음"))
    }

    @Test("정책 조회 + 출석 시작 전 → 시작 시각 안내")
    func guidanceShowsCheckInStartWithPolicy() async throws {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)
        let session = makeSession()
        viewModel.apply(schedules: [
            makeScheduleDetail(
                policy: makePolicy(
                    checkInStartAt: fixedNow.addingTimeInterval(600)  // 10분 뒤 시작
                )
            )
        ])

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
        viewModel.apply(schedules: [
            makeScheduleDetail(
                policy: makePolicy(
                    onTimeEndAt: fixedNow.addingTimeInterval(secondsLeft)
                )
            )
        ])

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

// MARK: - 일정 페이로드 반영

@MainActor
@Suite("ChallengerAttendanceViewModel — 일정 페이로드 반영 (도메인 규칙)")
struct ChallengerAttendanceViewModelScheduleTests {

    /// 회귀 박제 — 이 ViewModel 은 일정을 직접 조회하지 않는다. 조회를 되살리면 상위
    /// (`ActivityViewModel`)와 같은 엔드포인트를 두 번 때리게 된다.
    @Test("전달 전 → 일정 매핑이 nil")
    func scheduleLookupNilBeforeApply() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())

        #expect(viewModel.schedule(for: SessionID(value: "S-1")) == nil)
        #expect(viewModel.scheduleId(for: SessionID(value: "S-1")) == nil)
    }

    @Test("전달 후 → SessionID 와 같은 scheduleId 를 돌려준다")
    func scheduleLookupResolvesAppliedPayload() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())

        viewModel.apply(schedules: [makeScheduleDetail(scheduleId: "S-1")])

        #expect(viewModel.scheduleId(for: SessionID(value: "S-1")) == "S-1")
        #expect(viewModel.scheduleId(for: SessionID(value: "S-9")) == nil)
    }

    @Test("페이로드를 다시 전달하면 최신 목록으로 교체한다")
    func applyReplacesPayload() {
        let viewModel = makeViewModel(useCase: MockChallengerAttendanceUseCase())

        viewModel.apply(schedules: [makeScheduleDetail(scheduleId: "S-1")])
        viewModel.apply(schedules: [makeScheduleDetail(scheduleId: "S-2")])

        #expect(viewModel.schedules.map(\.scheduleId) == ["S-2"])
        #expect(viewModel.scheduleId(for: SessionID(value: "S-1")) == nil)
    }

    @Test("페이로드를 반영해도 일정 조회 요청은 보내지 않는다")
    func applyDoesNotQueryUseCase() {
        let useCase = MockChallengerAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.apply(schedules: [makeScheduleDetail()])

        #expect(useCase.fetchAvailableSchedulesCallCount == 0)
        #expect(useCase.fetchMyHistoryCallCount == 0)
    }
}

#endif
