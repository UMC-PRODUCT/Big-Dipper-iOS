//
//  ChallengerAttendanceUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/20/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

// MARK: - Helpers

/// `Int()` 변환이 실패하는 비숫자 일정 식별자 fixture (invalidScheduleId 분기 검증 공용)
private let invalidScheduleId = "invalid-id"

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
        hasDecisionMakerMember: false,
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
    locationProvider: MockLocationProvider = MockLocationProvider()
) -> ChallengerAttendanceUseCase {
    ChallengerAttendanceUseCase(
        repository: repository,
        locationProvider: locationProvider
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
        scheduleId: Int,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    )] = []

    private(set) var submitExcuseCalls: [(
        scheduleId: Int,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    )] = []

    // MARK: Protocol

    func requestAttendance(
        scheduleId: Int,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult {
        requestAttendanceCalls.append((scheduleId, latitude, longitude, locationVerified))
        return requestAttendanceResult
    }

    func submitExcuse(
        scheduleId: Int,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult {
        submitExcuseCalls.append((scheduleId, excuseReason, isVerified, latitude, longitude))
        return submitExcuseResult
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

    @Test("scheduleId Int 변환 실패 → DomainError.invalidScheduleId")
    func requestGPSAttendanceThrowsWhenScheduleIdInvalid() async {
        let useCase = makeUseCase()

        await #expect(throws: DomainError.invalidScheduleId(invalidScheduleId)) {
            _ = try await useCase.requestGPSAttendance(
                sessionId: SessionID(value: "S-1"),
                userId: UserID(value: "U-1"),
                scheduleId: invalidScheduleId
            )
        }
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
        #expect(call.scheduleId == 42)
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

    @Test("scheduleId Int 변환 실패 → DomainError.invalidScheduleId")
    func submitLateReasonThrowsWhenScheduleIdInvalid() async {
        let useCase = makeUseCase()

        await #expect(throws: DomainError.invalidScheduleId(invalidScheduleId)) {
            _ = try await useCase.submitLateReason(
                sessionId: SessionID(value: "S-1"),
                userId: UserID(value: "U-1"),
                reason: "지각 사유",
                scheduleId: invalidScheduleId
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
        #expect(call.scheduleId == 42)
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
