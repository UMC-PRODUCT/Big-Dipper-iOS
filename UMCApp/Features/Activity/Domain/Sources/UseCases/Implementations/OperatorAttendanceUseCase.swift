//
//  OperatorAttendanceUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation

/// `OperatorAttendanceUseCaseProtocol` 의 기본 구현체
///
/// 운영진 출석 관리 액션을 모두 `OperatorAttendanceRepositoryProtocol` 에 위임합니다.
/// 위임 외 도메인 로직이 없으므로 인자를 변형 없이 그대로 전달합니다.
/// `scheduleId` 는 서버 String ID 로 전 레이어 통일.
public final class OperatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol {

    // MARK: - Property

    private let repository: OperatorAttendanceRepositoryProtocol

    // MARK: - Init

    public init(repository: OperatorAttendanceRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - 조회

    public func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo] {
        try await repository.fetchAttendanceList(
            from: from,
            to: to,
            attendanceStatus: attendanceStatus
        )
    }

    public func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo {
        try await repository.fetchAttendanceDetail(
            scheduleId: scheduleId,
            attendanceStatus: attendanceStatus
        )
    }

    // MARK: - 액션

    public func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        try await repository.decideAttendances(
            scheduleId: scheduleId,
            decisions: decisions
        )
    }

    public func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        try await repository.updateScheduleLocation(
            scheduleId: scheduleId,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude
        )
    }
}
