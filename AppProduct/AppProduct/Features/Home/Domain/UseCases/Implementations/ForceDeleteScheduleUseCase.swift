//
//  ForceDeleteScheduleUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 5/18/26.
//

import Foundation

/// 출석 기록이 있는 일정을 강제 삭제하는 UseCase 구현체
final class ForceDeleteScheduleUseCase: ForceDeleteScheduleUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(scheduleId: Int) async throws {
        try await repository.forceDeleteSchedule(scheduleId: scheduleId)
    }
}
