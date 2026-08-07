//
//  ChallengerAttendanceUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/20/26.
//

import Foundation
import HomeDomain
import UMCFoundation

/// `ChallengerAttendanceUseCaseProtocol` 의 기본 구현체
///
/// - 위치/지오펜스 의존은 `LocationProviding` Protocol 로 주입.
/// - `scheduleId` 는 서버 String ID 로 전 레이어 통일 (Repository 도 String 으로 수신).
/// - 일정 조회는 `HomeDomain` 의 canonical `ScheduleRepositoryProtocol` 을 그대로 사용한다.
public final class ChallengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol {

    // MARK: - Property

    private let repository: ChallengerAttendanceRepositoryProtocol
    private let scheduleRepository: ScheduleRepositoryProtocol
    private let locationProvider: LocationProviding

    /// 일정 조회 구간 (일 단위)
    ///
    /// 서버가 `from~to` 를 **일정 시작 시각** 기준으로 거르므로, `from = now` 로 조회하면
    /// 이미 시작했지만 출석 창이 열려 있는 진행 중 일정이 빠진다. 그래서 하루를 앞당긴다.
    private enum LookupWindow {
        /// 출석 가능 목록 조회 시작 오프셋
        static let availableFromDays: Int = -1
        /// 출석 가능 목록 조회 종료 오프셋
        static let availableToDays: Int = 14
        /// 출석 이력 조회 시작 오프셋 (월 단위)
        static let historyFromMonths: Int = -6
    }

    // MARK: - Computed Property

    /// UI 상태 표시용 fallback — 추적 중인 지오펜스 중 어느 하나라도 안에 있는지.
    /// 특정 출석 가드는 `requestGPSAttendance` 내부의 `isInside(geofenceId:)` 식별자 기반 판정 사용.
    public var isInsideGeofence: Bool {
        locationProvider.isInsideAnyGeofence
    }

    public var isLocationAuthorized: Bool {
        locationProvider.isAuthorized
    }

    // MARK: - Init

    public init(
        repository: ChallengerAttendanceRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol,
        locationProvider: LocationProviding
    ) {
        self.repository = repository
        self.scheduleRepository = scheduleRepository
        self.locationProvider = locationProvider
    }

    // MARK: - 일정 조회

    /// 출석 가능한 일정 목록 조회
    ///
    /// 출석 정책이 붙어 있고, 본인이 참여자이며, 출석 창이 아직 안 닫힌 일정만 남깁니다.
    /// 출석 창이 아직 열리지 않은 일정도 포함해 View 가 "출석 전" 으로 표시할 수 있게 합니다.
    public func fetchAvailableSchedules(now: Date) async throws -> [ScheduleDetailData] {
        let calendar = Calendar.kstGregorian
        let from = calendar.date(
            byAdding: .day, value: LookupWindow.availableFromDays, to: now
        ) ?? now
        let to = calendar.date(
            byAdding: .day, value: LookupWindow.availableToDays, to: now
        ) ?? now

        let schedules = try await fetchAttendanceSchedules(from: from, to: to)
        return schedules.filter {
            $0.requiresAttendanceApproval
                && $0.isParticipant
                && $0.attendanceWindowEndsAt > now
        }
    }

    /// 내 출석 이력 조회
    ///
    /// 최근 6개월 구간에서 출석 정책이 붙은 일정만 남깁니다.
    public func fetchMyHistory(now: Date) async throws -> [ScheduleDetailData] {
        let from = Calendar.kstGregorian.date(
            byAdding: .month, value: LookupWindow.historyFromMonths, to: now
        ) ?? now

        let schedules = try await fetchAttendanceSchedules(from: from, to: now)
        return schedules.filter(\.requiresAttendanceApproval)
    }

    // MARK: - 출석 액션

    /// GPS 기반 출석 요청
    public func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: String
    ) async throws -> Attendance {
        guard locationProvider.isAuthorized else {
            throw LocationError.notAuthorized
        }

        guard let coordinate = locationProvider.currentCoordinate else {
            throw LocationError.locationFailed("현재 위치를 가져올 수 없습니다.")
        }

        guard locationProvider.isInside(geofenceId: scheduleId) else {
            throw DomainError.attendanceOutOfRange
        }

        let result = try await repository.requestAttendance(
            scheduleId: scheduleId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locationVerified: true
        )

        return result.toAttendance(sessionId: sessionId, userId: userId)
    }

    /// 지각 사유 제출
    ///
    /// `submitAbsentReason` 과 함께 현재는 동일 서버 엔드포인트(`submitExcuse`)로 수렴하지만,
    /// 호출부(ViewModel)가 "지각"과 "불참"을 도메인 어휘로 구분해 호출하도록 별도 진입점으로 유지합니다.
    /// 사유 종류별 분기(지각=부분 출석 증빙, 불참=별도 승인 흐름 등)가 생기면 이 지점에서 갈라집니다.
    public func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        try await submitExcuse(
            sessionId: sessionId,
            userId: userId,
            reason: reason,
            scheduleId: scheduleId
        )
    }

    /// 불참 사유 제출
    ///
    /// `submitLateReason` 참고 — 동일 엔드포인트(`submitExcuse`)로 수렴하나
    /// 도메인 의미가 달라 호출부 명확성을 위해 진입점을 분리합니다.
    public func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        try await submitExcuse(
            sessionId: sessionId,
            userId: userId,
            reason: reason,
            scheduleId: scheduleId
        )
    }

    // MARK: - 시간 윈도우

    /// 기준 시각(`now`)이 어느 출석 시간대에 속하는지 판정
    public func isWithinAttendanceTime(
        info: SessionInfo,
        now: Date
    ) -> AttendanceTimeWindow {
        let onTimeThreshold = TimeInterval(
            AttendancePolicy.onTimeThresholdMinutes * 60
        )
        let lateThreshold = TimeInterval(
            AttendancePolicy.lateThresholdMinutes * 60
        )
        let startTime = info.startTime

        if info.isAllDay {
            if now < startTime.addingTimeInterval(-onTimeThreshold) {
                return .tooEarly
            }
            if now <= info.endTime {
                return .onTime
            }
            return .expired
        }

        if now < startTime.addingTimeInterval(-onTimeThreshold) {
            return .tooEarly
        }
        if now <= startTime.addingTimeInterval(onTimeThreshold) {
            return .onTime
        }
        if now <= startTime.addingTimeInterval(lateThreshold) {
            return .lateWindow
        }
        return .expired
    }

    // MARK: - 위치/지오펜스

    /// 현재 좌표 → 주소(도메인 모델) 역지오코딩
    public func getAddressToCurrentLocation() async throws -> Address {
        guard let coordinate = locationProvider.currentCoordinate else {
            throw LocationError.locationFailed("주소를 찾을 수 없습니다.")
        }
        return try await locationProvider.reverseGeocode(coordinate: coordinate)
    }

    /// 등록된 모든 지오펜스 모니터링 중지
    public func stopGeofenceMonitoring() async {
        await locationProvider.stopAllGeofenceMonitoring()
    }

    // MARK: - Private

    /// 출석 필수 일정을 기간으로 조회해 시작 시각 오름차순 평탄 목록으로 돌려준다.
    ///
    /// canonical Repository 는 캘린더 표시를 위해 KST 자정 기준 날짜별 딕셔너리를 반환하므로,
    /// 출석 화면이 쓰는 단일 목록으로 펼친다. 딕셔너리는 순서를 보장하지 않아 정렬이 필요하다.
    private func fetchAttendanceSchedules(
        from: Date,
        to: Date
    ) async throws -> [ScheduleDetailData] {
        let grouped = try await scheduleRepository.fetchMySchedules(
            from: from,
            to: to,
            isAttendanceRequired: true
        )
        return grouped.values.flatMap { $0 }.sorted { $0.startsAt < $1.startsAt }
    }

    /// 사유 결석/지각 공통 제출
    ///
    /// 좌표 미보유 시 `isVerified = false` 로 보고 (lat/lng 0.0 폴백)
    private func submitExcuse(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.attendanceReasonRequired
        }

        let coordinate = locationProvider.currentCoordinate

        let result = try await repository.submitExcuse(
            scheduleId: scheduleId,
            excuseReason: reason,
            isVerified: coordinate != nil,
            latitude: coordinate?.latitude ?? 0.0,
            longitude: coordinate?.longitude ?? 0.0
        )
        return result.toAttendance(sessionId: sessionId, userId: userId)
    }
}
