//
//  UpdateScheduleUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 부분 수정 UseCase 구현체
public final class UpdateScheduleUseCase: UpdateScheduleUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(scheduleId: String, request: ScheduleUpdateRequest) async throws {
        try await repository.updateSchedule(scheduleId: scheduleId, request: request)
    }
}
