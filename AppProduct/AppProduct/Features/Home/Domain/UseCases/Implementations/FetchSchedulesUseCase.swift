//
//  FetchSchedulesUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

/// 기간 내 내 일정 조회 UseCase 구현 (V2)
final class FetchSchedulesUseCase: FetchSchedulesUseCaseProtocol {

    // MARK: - Property

    private let repository: HomeRepositoryProtocol

    // MARK: - Init

    init(repository: HomeRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(
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
