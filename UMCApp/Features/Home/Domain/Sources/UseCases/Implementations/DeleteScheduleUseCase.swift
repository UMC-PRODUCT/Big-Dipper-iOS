//
//  DeleteScheduleUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 삭제 UseCase 구현체
public final class DeleteScheduleUseCase: DeleteScheduleUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(scheduleId: String) async throws {
        try await repository.deleteSchedule(scheduleId: scheduleId)
    }
}
