//
//  ForceDeleteScheduleUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 강제 삭제 UseCase 구현체
public final class ForceDeleteScheduleUseCase: ForceDeleteScheduleUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(scheduleId: String) async throws {
        try await repository.forceDeleteSchedule(scheduleId: scheduleId)
    }
}
