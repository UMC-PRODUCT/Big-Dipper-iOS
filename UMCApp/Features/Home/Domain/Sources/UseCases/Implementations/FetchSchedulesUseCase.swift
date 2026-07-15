//
//  FetchSchedulesUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 2/13/26.
//

import Foundation

/// 기간 내 내 일정 조회 UseCase 구현체
public final class FetchSchedulesUseCase: FetchSchedulesUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]] {
        try await repository.fetchMySchedules(
            from: from,
            to: to,
            isAttendanceRequired: isAttendanceRequired
        )
    }
}
