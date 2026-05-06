//
//  GenerateScheduleUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

/// 일정 생성 UseCase 구현
///
/// `ScheduleRepositoryProtocol`에 위임하여 일정을 생성합니다.
///
/// - SeeAlso: ``GenerateScheduleUseCaseProtocol``, ``ScheduleRepositoryProtocol``
final class GenerateScheduleUseCase: GenerateScheduleUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleRepositoryProtocol

    // MARK: - Init

    init(repository: ScheduleRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    @discardableResult
    func execute(schedule: GenerateScheduleRequetDTO) async throws -> Int {
        try await repository.generateSchedule(schedule: schedule)
    }
}
