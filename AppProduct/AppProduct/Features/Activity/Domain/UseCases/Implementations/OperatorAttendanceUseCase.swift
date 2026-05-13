//
//  OperatorAttendanceUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/9/26.
//

import Foundation

// MARK: - Implementation

/// 운영진 출석 관리 UseCase 구현체
final class OperatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol {

    // MARK: - Property

    private let repository: OperatorAttendanceRepositoryProtocol

    // MARK: - Init

    init(repository: OperatorAttendanceRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func decideAttendances(
        scheduleId: Int,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        try await repository.decideAttendances(
            scheduleId: scheduleId,
            decisions: decisions
        )
    }

    func updateScheduleLocation(
        scheduleId: Int,
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

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo] {
        try await repository.fetchAttendanceList(
            from: from,
            to: to,
            attendanceStatus: attendanceStatus
        )
    }

    func fetchAttendanceDetail(
        scheduleId: Int,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> ScheduleAttendanceInfo {
        try await repository.fetchAttendanceDetail(
            scheduleId: scheduleId,
            attendanceStatus: attendanceStatus
        )
    }
}
