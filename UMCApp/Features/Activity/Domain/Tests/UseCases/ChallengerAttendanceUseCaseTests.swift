//
//  ChallengerAttendanceUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/20/26.
//

import Foundation
import HomeDomain
import Testing
import UMCFoundation
@testable import ActivityDomain

// MARK: - Helpers

private func makeCoordinate(
    latitude: Double = 37.5,
    longitude: Double = 127.0
) -> Coordinate {
    Coordinate(latitude: latitude, longitude: longitude)
}

private func makeDecisionResult(
    status: ParticipantAttendanceStatus = .present,
    excuseReason: String? = nil,
    decisionReason: String? = nil
) -> AttendanceDecisionResult {
    AttendanceDecisionResult(
        status: status,
        decidedAt: Date(timeIntervalSince1970: 1_000),
        decisionReason: decisionReason,
        excuseReason: excuseReason,
        latitude: nil,
        longitude: nil,
        decisionMakerMemberInfo: nil,
        isPendingDecision: false
    )
}

private func makeSessionInfo(
    startTime: Date,
    endTime: Date,
    isAllDay: Bool = false
) -> SessionInfo {
    SessionInfo(
        sessionId: SessionID(value: "S-1"),
        iconName: "calendar.badge",
        title: "1주차 OT",
        week: 1,
        startTime: startTime,
        endTime: endTime,
        location: Coordinate(latitude: 37.5, longitude: 127.0),
        isAllDay: isAllDay
    )
}

private func makeUseCase(
    repository: MockChallengerAttendanceRepository = MockChallengerAttendanceRepository(),
    scheduleRepository: MockScheduleRepository = MockScheduleRepository(),
    locationProvider: MockLocationProvider = MockLocationProvider()
) -> ChallengerAttendanceUseCase {
    ChallengerAttendanceUseCase(
        repository: repository,
        scheduleRepository: scheduleRepository,
        locationProvider: locationProvider
    )
}

/// 출석 정책이 붙은 일정 픽스처.
///
/// `policyOffsets` 는 기준 시각 대비 (체크인 시작, 정시 마감, 지각 마감) 초 오프셋.
/// `nil` 이면 출석 비필수 일정(정책 미부착)을 뜻한다.
private func makeSchedule(
    scheduleId: String,
    startsAt: Date,
    endsAt: Date,
    isParticipant: Bool = true,
    policy: ScheduleAttendancePolicy?
) -> ScheduleDetailData {
    ScheduleDetailData(
        scheduleId: scheduleId,
        name: "일정 \(scheduleId)",
        description: "",
        tags: [],
        startsAt: startsAt,
        endsAt: endsAt,
        isParticipant: isParticipant,
        attendancePolicy: policy
    )
}

private func makePolicy(
    checkInStartAt: Date,
    onTimeEndAt: Date,
    lateEndAt: Date
) -> ScheduleAttendancePolicy {
    ScheduleAttendancePolicy(
        checkInStartAt: checkInStartAt,
        onTimeEndAt: onTimeEndAt,
        lateEndAt: lateEndAt
    )
}

// MARK: - Mocks

#if DEBUG

private final class MockChallengerAttendanceRepository: @unchecked Sendable,
    ChallengerAttendanceRepositoryProtocol {

    // MARK: 입출력 기록

    var requestAttendanceResult: AttendanceDecisionResult = makeDecisionResult()
    var submitExcuseResult: AttendanceDecisionResult = makeDecisionResult(
        status: .excusedPending,
        excuseReason: "사유"
    )

    private(set) var requestAttendanceCalls: [(
        scheduleId: String,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    )] = []

    private(set) var submitExcuseCalls: [(
        scheduleId: String,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    )] = []

    // MARK: Protocol

    func requestAttendance(
        scheduleId: String,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult {
        requestAttendanceCalls.append((scheduleId, latitude, longitude, locationVerified))
        return requestAttendanceResult
    }

    func submitExcuse(
        scheduleId: String,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult {
        submitExcuseCalls.append((scheduleId, excuseReason, isVerified, latitude, longitude))
        return submitExcuseResult
    }
}

private final class MockScheduleRepository: @unchecked Sendable, ScheduleRepositoryProtocol {

    /// 반환할 일정 목록 (Repository 계약대로 KST 자정 기준 날짜별로 그룹핑해 돌려준다)
    var schedules: [ScheduleDetailData] = []
    var fetchError: Error?

    private(set) var fetchCalls: [(from: Date, to: Date, isAttendanceRequired: Bool)] = []

    func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]] {
        fetchCalls.append((from, to, isAttendanceRequired))
        if let fetchError {
            throw fetchError
        }
        let calendar = Calendar.kstGregorian
        return Dictionary(grouping: schedules) { calendar.startOfDay(for: $0.startsAt) }
    }

    // MARK: 계약 밖 메서드 (호출 시 실패 — 출석 UseCase 는 조회만 사용)

    func fetchScheduleDetail(scheduleId: String) async throws -> ScheduleDetailData {
        fatalError("fetchScheduleDetail 은 ChallengerAttendanceUseCase 계약 밖입니다.")
    }

    func createSchedule(_ request: ScheduleCreationRequest) async throws -> String {
        fatalError("createSchedule 은 ChallengerAttendanceUseCase 계약 밖입니다.")
    }

    func deleteSchedule(scheduleId: String) async throws {
        fatalError("deleteSchedule 은 ChallengerAttendanceUseCase 계약 밖입니다.")
    }
}

private final class MockLocationProvider: @unchecked Sendable, LocationProviding {

    var isAuthorized: Bool = true
    var isInsideAnyGeofence: Bool = true
    var currentCoordinate: Coordinate? = makeCoordinate()
    var reverseGeocodeResult: Address = Address(
        fullAddress: "서울특별시 성북구 삼선동",
        city: "서울특별시",
        district: "성북구"
    )
    var reverseGeocodeError: Error?

    /// `isInside(geofenceId:)` 의 응답을 컨트롤하는 stub
    /// - key: geofenceId, value: 안에 있는지 여부.
    /// - key 없는 geofenceId 는 `isInsideDefault` 반환.
    var isInsideMap: [String: Bool] = [:]
    var isInsideDefault: Bool = true

    private(set) var stopAllGeofenceMonitoringCallCount: Int = 0
    private(set) var isInsideQueries: [String] = []

    func isInside(geofenceId: String) -> Bool {
        isInsideQueries.append(geofenceId)
        return isInsideMap[geofenceId] ?? isInsideDefault
    }

    func reverseGeocode(coordinate: Coordinate) async throws -> Address {
        if let error = reverseGeocodeError {
            throw error
        }
        return reverseGeocodeResult
    }

    func stopAllGeofenceMonitoring() async {
        stopAllGeofenceMonitoringCallCount += 1
    }
}

#endif

// MARK: - GPS 출석 요청

@Suite("ChallengerAttendanceUseCase — GPS 출석 요청 (도메인 규칙)")
struct ChallengerAttendanceUseCaseGPSTests {

    @Test("권한 미부여 → LocationError.notAuthorized")
    func requestGPSAttendanceThrowsWhenNotAuthorized() async {
        let location = MockLocationProvider()
        location.isAuthorized = false
        let useCase = makeUseCase(locationProvider: location)

        await #expect(throws: LocationError.self) {
            _ = try await useCase.requestGPSAttendance(
                sessionId: SessionID(value: "S-1"),
                userId: UserID(value: "U-1"),
                scheduleId: "100"
            )
        }
    }

    @Test("현재 좌표 nil → LocationError.locationFailed")
    func requestGPSAttendanceThrowsWhenCoordinateMissing() async {
        let location = MockLocationProvider()
        location.currentCoordinate = nil
        let useCase = makeUseCase(locationProvider: location)

        await #expect(throws: LocationError.self) {
            _ = try await useCase.requestGPSAttendance(
                sessionId: SessionID(value: "S-1"),
                userId: UserID(value: "U-1"),
                scheduleId: "100"
            )
        }
    }

    @Test("scheduleId 식별 지오펜스 밖 → DomainError.attendanceOutOfRange")
    func requestGPSAttendanceThrowsWhenOutsideGeofence() async {
        let location = MockLocationProvider()
        location.isInsideMap = ["100": false]   // 본 일정 지오펜스만 false
        location.isInsideDefault = true         // 다른 지오펜스는 true 라 해도 무관
        let useCase = makeUseCase(locationProvider: location)

        await #expect(throws: DomainError.attendanceOutOfRange) {
            _ = try await useCase.requestGPSAttendance(
                sessionId: SessionID(value: "S-1"),
                userId: UserID(value: "U-1"),
                scheduleId: "100"
            )
        }
        // 정확히 scheduleId 로 질의했는지 검증 (식별자 기반)
        #expect(location.isInsideQueries == ["100"])
    }

    @Test("정상 — Repository 위임 + Attendance 매핑 + locationVerified=true")
    func requestGPSAttendanceSucceeds() async throws {
        let repository = MockChallengerAttendanceRepository()
        repository.requestAttendanceResult = makeDecisionResult(status: .present)
        let location = MockLocationProvider()
        location.currentCoordinate = makeCoordinate(latitude: 37.6, longitude: 127.1)
        location.isInsideMap = ["42": true]
        let useCase = makeUseCase(repository: repository, locationProvider: location)

        let attendance = try await useCase.requestGPSAttendance(
            sessionId: SessionID(value: "S-7"),
            userId: UserID(value: "U-3"),
            scheduleId: "42"
        )

        #expect(repository.requestAttendanceCalls.count == 1)
        let call = try #require(repository.requestAttendanceCalls.first)
        #expect(call.scheduleId == "42")
        #expect(call.latitude == 37.6)
        #expect(call.longitude == 127.1)
        #expect(call.locationVerified == true)

        #expect(attendance.sessionId == SessionID(value: "S-7"))
        #expect(attendance.userId == UserID(value: "U-3"))
        #expect(attendance.status == .present)
        #expect(attendance.type == .gps)
    }
}

// MARK: - 사유 제출

@Suite("ChallengerAttendanceUseCase — 사유 제출 (도메인 규칙)")
struct ChallengerAttendanceUseCaseExcuseTests {

    @Test(
        "빈 사유(공백 trim 결과 빈 문자열) → DomainError.attendanceReasonRequired",
        arguments: ["", "   ", "\n\t  "]
    )
    func submitLateReasonRejectsBlank(reason: String) async {
        let useCase = makeUseCase()

        await #expect(throws: DomainError.attendanceReasonRequired) {
            _ = try await useCase.submitLateReason(
                sessionId: SessionID(value: "S-1"),
                userId: UserID(value: "U-1"),
                reason: reason,
                scheduleId: "100"
            )
        }
    }

    @Test("지각 사유 정상 제출 → Repository 위임 + 좌표 동봉 + isVerified=true")
    func submitLateReasonSucceedsWithCoordinate() async throws {
        let repository = MockChallengerAttendanceRepository()
        repository.submitExcuseResult = makeDecisionResult(
            status: .latePending,
            excuseReason: "지각 사유"
        )
        let location = MockLocationProvider()
        location.currentCoordinate = makeCoordinate(latitude: 37.7, longitude: 127.2)
        let useCase = makeUseCase(repository: repository, locationProvider: location)

        let attendance = try await useCase.submitLateReason(
            sessionId: SessionID(value: "S-1"),
            userId: UserID(value: "U-1"),
            reason: "지각 사유",
            scheduleId: "42"
        )

        let call = try #require(repository.submitExcuseCalls.first)
        #expect(call.scheduleId == "42")
        #expect(call.excuseReason == "지각 사유")
        #expect(call.isVerified == true)
        #expect(call.latitude == 37.7)
        #expect(call.longitude == 127.2)

        #expect(attendance.status == .pendingApproval)
        #expect(attendance.type == .reason)
        #expect(attendance.reason == "지각 사유")
    }

    @Test("좌표 미보유 시 → isVerified=false + lat/lng 0.0 폴백")
    func submitAbsentReasonFallsBackWhenCoordinateMissing() async throws {
        let repository = MockChallengerAttendanceRepository()
        repository.submitExcuseResult = makeDecisionResult(
            status: .excusedPending,
            excuseReason: "결석 사유"
        )
        let location = MockLocationProvider()
        location.currentCoordinate = nil
        let useCase = makeUseCase(repository: repository, locationProvider: location)

        _ = try await useCase.submitAbsentReason(
            sessionId: SessionID(value: "S-1"),
            userId: UserID(value: "U-1"),
            reason: "결석 사유",
            scheduleId: "7"
        )

        let call = try #require(repository.submitExcuseCalls.first)
        #expect(call.isVerified == false)
        #expect(call.latitude == 0.0)
        #expect(call.longitude == 0.0)
    }

    @Test("결석 사유 정상 제출 → Repository 위임 + Attendance.reason 일치")
    func submitAbsentReasonSucceeds() async throws {
        let repository = MockChallengerAttendanceRepository()
        repository.submitExcuseResult = makeDecisionResult(
            status: .excusedPending,
            excuseReason: "결석 사유"
        )
        let useCase = makeUseCase(repository: repository)

        let attendance = try await useCase.submitAbsentReason(
            sessionId: SessionID(value: "S-1"),
            userId: UserID(value: "U-1"),
            reason: "결석 사유",
            scheduleId: "5"
        )

        #expect(repository.submitExcuseCalls.count == 1)
        #expect(attendance.reason == "결석 사유")
        #expect(attendance.type == .reason)
        #expect(attendance.status == .pendingApproval)
    }
}

// MARK: - 출석 시간 윈도우

@Suite("ChallengerAttendanceUseCase — 출석 시간 윈도우 (도메인 규칙)")
struct ChallengerAttendanceUseCaseTimeWindowTests {

    // 결정론적 기준 시각: epoch 10_000 (1970-01-01 02:46:40 KST).
    // 모든 케이스는 `start` 를 이 기준으로부터 상대적으로 정의하여 wall-clock 비의존.
    private static let fixedNow = Date(timeIntervalSince1970: 10_000)

    private static let onTimeSec = TimeInterval(
        AttendancePolicy.onTimeThresholdMinutes * 60
    )
    private static let lateSec = TimeInterval(
        AttendancePolicy.lateThresholdMinutes * 60
    )

    @Test("일반 — 시작 onTime 임계 이전 → tooEarly")
    func nonAllDayBeforeOnTime() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow.addingTimeInterval(Self.onTimeSec + 60),
            endTime: Self.fixedNow.addingTimeInterval(Self.onTimeSec + 3_600)
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .tooEarly)
    }

    @Test("일반 — 시작 정시(now == startTime) → onTime")
    func nonAllDayOnTimeAtStart() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow,
            endTime: Self.fixedNow.addingTimeInterval(3_600)
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .onTime)
    }

    @Test("일반 — onTime 경계값(now == start + onTime) → onTime (boundary 포함)")
    func nonAllDayOnTimeUpperBoundary() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow.addingTimeInterval(-Self.onTimeSec),
            endTime: Self.fixedNow.addingTimeInterval(3_600)
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .onTime)
    }

    @Test("일반 — onTime 초과 ~ late 임계 → lateWindow")
    func nonAllDayLateWindow() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow.addingTimeInterval(-(Self.onTimeSec + 60)),
            endTime: Self.fixedNow.addingTimeInterval(3_600)
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .lateWindow)
    }

    @Test("일반 — late 임계 초과 → expired")
    func nonAllDayExpired() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow.addingTimeInterval(-(Self.lateSec + 60)),
            endTime: Self.fixedNow.addingTimeInterval(3_600)
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .expired)
    }

    @Test("종일 — 시작 onTime 임계 이전 → tooEarly")
    func allDayBeforeOnTime() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow.addingTimeInterval(Self.onTimeSec + 60),
            endTime: Self.fixedNow.addingTimeInterval(Self.onTimeSec + 86_400),
            isAllDay: true
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .tooEarly)
    }

    @Test("종일 — 시작 onTime~종료 구간 → onTime (lateWindow 미분기)")
    func allDayWholeDayIsOnTime() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow.addingTimeInterval(-3_600),
            endTime: Self.fixedNow.addingTimeInterval(3_600),
            isAllDay: true
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .onTime)
    }

    @Test("종일 — 종료 시각 지남 → expired")
    func allDayAfterEndIsExpired() {
        let useCase = makeUseCase()
        let info = makeSessionInfo(
            startTime: Self.fixedNow.addingTimeInterval(-86_400),
            endTime: Self.fixedNow.addingTimeInterval(-60),
            isAllDay: true
        )
        #expect(useCase.isWithinAttendanceTime(info: info, now: Self.fixedNow) == .expired)
    }

    @Test("프로덕션 편의 오버로드 — now 미주입 시 Date() 사용")
    func defaultOverloadUsesCurrentDate() {
        let useCase = makeUseCase()
        // 시작이 지금으로부터 +1h, end +2h → tooEarly 윈도우 안에 있음 (현재 시각 기준)
        let now = Date()
        let info = makeSessionInfo(
            startTime: now.addingTimeInterval(3_600),
            endTime: now.addingTimeInterval(7_200)
        )
        // 결정론은 아니지만, `+1h 시작`은 onTime 임계(±10분) 밖이라
        // 모든 wall-clock jitter 에서 tooEarly 가 보장됨 (결정론 OK).
        #expect(useCase.isWithinAttendanceTime(info: info) == .tooEarly)
    }
}

// MARK: - 위치/지오펜스 위임

@Suite("ChallengerAttendanceUseCase — 위치 위임 (도메인 규칙)")
struct ChallengerAttendanceUseCaseLocationTests {

    @Test("isInsideGeofence / isLocationAuthorized — LocationProvider 위임")
    func computedPropertiesDelegate() {
        let location = MockLocationProvider()
        location.isAuthorized = false
        location.isInsideAnyGeofence = true
        let useCase = makeUseCase(locationProvider: location)

        #expect(useCase.isLocationAuthorized == false)
        #expect(useCase.isInsideGeofence == true)
    }

    @Test("getAddressToCurrentLocation — 좌표 nil → LocationError.locationFailed")
    func getAddressThrowsWhenCoordinateMissing() async {
        let location = MockLocationProvider()
        location.currentCoordinate = nil
        let useCase = makeUseCase(locationProvider: location)

        await #expect(throws: LocationError.self) {
            _ = try await useCase.getAddressToCurrentLocation()
        }
    }

    @Test("getAddressToCurrentLocation — 정상 위임 결과 반환 (Address 도메인 모델)")
    func getAddressDelegates() async throws {
        let expected = Address(
            fullAddress: "서울특별시 종로구 사직동",
            city: "서울특별시",
            district: "종로구"
        )
        let location = MockLocationProvider()
        location.currentCoordinate = makeCoordinate()
        location.reverseGeocodeResult = expected
        let useCase = makeUseCase(locationProvider: location)

        let address = try await useCase.getAddressToCurrentLocation()

        #expect(address == expected)
        #expect(address.city == "서울특별시")
        #expect(address.district == "종로구")
    }

    @Test("stopGeofenceMonitoring — LocationProvider 위임 호출")
    func stopGeofenceMonitoringDelegates() async {
        let location = MockLocationProvider()
        let useCase = makeUseCase(locationProvider: location)

        await useCase.stopGeofenceMonitoring()

        #expect(location.stopAllGeofenceMonitoringCallCount == 1)
    }
}

// MARK: - 출석 가능 일정 조회

@Suite("ChallengerAttendanceUseCase — 출석 가능 일정 조회 (도메인 규칙)")
struct ChallengerAttendanceUseCaseAvailableSchedulesTests {

    /// 결정론적 기준 시각 (epoch 1_700_000_000)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// 기준 시각 대비 초 오프셋으로 만든 일정 픽스처
    private func schedule(
        id: String,
        startOffset: TimeInterval,
        isParticipant: Bool = true,
        hasPolicy: Bool = true,
        lateEndOffset: TimeInterval? = nil
    ) -> ScheduleDetailData {
        let start = now.addingTimeInterval(startOffset)
        let policy = hasPolicy
            ? makePolicy(
                checkInStartAt: start.addingTimeInterval(-600),
                onTimeEndAt: start.addingTimeInterval(600),
                lateEndAt: start.addingTimeInterval(lateEndOffset ?? 1_800)
            )
            : nil
        return makeSchedule(
            scheduleId: id,
            startsAt: start,
            endsAt: start.addingTimeInterval(3_600),
            isParticipant: isParticipant,
            policy: policy
        )
    }

    @Test("출석 필수 필터를 켜고 -1일 ~ +14일 구간을 조회한다")
    func fetchAvailableSchedulesQueriesExpectedWindow() async throws {
        let scheduleRepository = MockScheduleRepository()
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        _ = try await useCase.fetchAvailableSchedules(now: now)

        let call = try #require(scheduleRepository.fetchCalls.first)
        let calendar = Calendar.kstGregorian
        #expect(call.isAttendanceRequired)
        #expect(call.from == calendar.date(byAdding: .day, value: -1, to: now))
        #expect(call.to == calendar.date(byAdding: .day, value: 14, to: now))
    }

    @Test("출석 정책이 없는 일정은 제외한다")
    func fetchAvailableSchedulesExcludesScheduleWithoutPolicy() async throws {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.schedules = [
            schedule(id: "1", startOffset: 3_600),
            schedule(id: "2", startOffset: 3_600, hasPolicy: false),
        ]
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        let result = try await useCase.fetchAvailableSchedules(now: now)

        #expect(result.map(\.scheduleId) == ["1"])
    }

    @Test("본인이 참여자가 아닌 일정은 제외한다")
    func fetchAvailableSchedulesExcludesNonParticipant() async throws {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.schedules = [
            schedule(id: "1", startOffset: 3_600),
            schedule(id: "2", startOffset: 3_600, isParticipant: false),
        ]
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        let result = try await useCase.fetchAvailableSchedules(now: now)

        #expect(result.map(\.scheduleId) == ["1"])
    }

    @Test("출석 창이 이미 닫힌 일정은 제외하고, 아직 열리지 않은 일정은 포함한다")
    func fetchAvailableSchedulesKeepsOpenWindowOnly() async throws {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.schedules = [
            // 지각 마감·종료 모두 과거 → 창이 닫힘
            schedule(id: "closed", startOffset: -7_200, lateEndOffset: -3_600),
            // 아직 시작 전 → 창이 열리기 전이지만 목록에는 남아야 함
            schedule(id: "upcoming", startOffset: 7_200),
        ]
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        let result = try await useCase.fetchAvailableSchedules(now: now)

        #expect(result.map(\.scheduleId) == ["upcoming"])
    }

    @Test("날짜별 그룹 응답을 시작 시각 오름차순 단일 목록으로 펼친다")
    func fetchAvailableSchedulesFlattensSortedByStart() async throws {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.schedules = [
            schedule(id: "late", startOffset: 3 * 86_400),
            schedule(id: "early", startOffset: 3_600),
            schedule(id: "mid", startOffset: 86_400),
        ]
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        let result = try await useCase.fetchAvailableSchedules(now: now)

        #expect(result.map(\.scheduleId) == ["early", "mid", "late"])
    }

    @Test("Repository 에러는 그대로 전파한다")
    func fetchAvailableSchedulesPropagatesError() async {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.fetchError = DomainError.attendanceOutOfRange
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        await #expect(throws: DomainError.attendanceOutOfRange) {
            _ = try await useCase.fetchAvailableSchedules(now: now)
        }
    }
}

// MARK: - 출석 이력 조회

@Suite("ChallengerAttendanceUseCase — 출석 이력 조회 (도메인 규칙)")
struct ChallengerAttendanceUseCaseHistoryTests {

    /// 결정론적 기준 시각 (epoch 1_700_000_000)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pastSchedule(
        id: String,
        startOffset: TimeInterval,
        isParticipant: Bool = true,
        hasPolicy: Bool = true
    ) -> ScheduleDetailData {
        let start = now.addingTimeInterval(startOffset)
        let policy = hasPolicy
            ? makePolicy(
                checkInStartAt: start.addingTimeInterval(-600),
                onTimeEndAt: start.addingTimeInterval(600),
                lateEndAt: start.addingTimeInterval(1_800)
            )
            : nil
        return makeSchedule(
            scheduleId: id,
            startsAt: start,
            endsAt: start.addingTimeInterval(3_600),
            isParticipant: isParticipant,
            policy: policy
        )
    }

    @Test("출석 필수 필터를 켜고 -6개월 ~ 현재 구간을 조회한다")
    func fetchMyHistoryQueriesExpectedWindow() async throws {
        let scheduleRepository = MockScheduleRepository()
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        _ = try await useCase.fetchMyHistory(now: now)

        let call = try #require(scheduleRepository.fetchCalls.first)
        #expect(call.isAttendanceRequired)
        #expect(call.from == Calendar.kstGregorian.date(byAdding: .month, value: -6, to: now))
        #expect(call.to == now)
    }

    @Test("출석 정책이 없는 일정은 이력에서 제외한다")
    func fetchMyHistoryExcludesScheduleWithoutPolicy() async throws {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.schedules = [
            pastSchedule(id: "1", startOffset: -86_400),
            pastSchedule(id: "2", startOffset: -86_400, hasPolicy: false),
        ]
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        let result = try await useCase.fetchMyHistory(now: now)

        #expect(result.map(\.scheduleId) == ["1"])
    }

    @Test("참여 여부·출석 창 마감은 이력 필터에 관여하지 않는다")
    func fetchMyHistoryKeepsClosedAndNonParticipantSchedules() async throws {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.schedules = [
            pastSchedule(id: "closed", startOffset: -172_800),
            pastSchedule(id: "notParticipant", startOffset: -86_400, isParticipant: false),
        ]
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        let result = try await useCase.fetchMyHistory(now: now)

        #expect(result.map(\.scheduleId) == ["closed", "notParticipant"])
    }

    @Test("Repository 에러는 그대로 전파한다")
    func fetchMyHistoryPropagatesError() async {
        let scheduleRepository = MockScheduleRepository()
        scheduleRepository.fetchError = DomainError.attendanceOutOfRange
        let useCase = makeUseCase(scheduleRepository: scheduleRepository)

        await #expect(throws: DomainError.attendanceOutOfRange) {
            _ = try await useCase.fetchMyHistory(now: now)
        }
    }
}
