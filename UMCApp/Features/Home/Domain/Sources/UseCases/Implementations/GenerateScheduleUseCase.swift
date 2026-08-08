//
//  GenerateScheduleUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// 일정 생성 UseCase 구현체
public final class GenerateScheduleUseCase: GenerateScheduleUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    @discardableResult
    public func execute(request: ScheduleCreationRequest) async throws -> String {
        try await repository.createSchedule(request)
    }
}
