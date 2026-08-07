//
//  FetchScheduleDetailUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/6/26.
//

import Foundation

/// 단일 일정 상세 조회 UseCase 구현체
public final class FetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(scheduleId: String) async throws -> ScheduleDetailData {
        try await repository.fetchScheduleDetail(scheduleId: scheduleId)
    }
}
