//
//  FetchScheduleCapabilitiesUseCase.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 일정 생성/수정 권한 조회 UseCase 구현
///
/// `ScheduleCapabilitiesRepositoryProtocol` 에 단순 위임합니다.
///
/// - SeeAlso: ``FetchScheduleCapabilitiesUseCaseProtocol``, ``ScheduleCapabilitiesRepositoryProtocol``
final class FetchScheduleCapabilitiesUseCase: FetchScheduleCapabilitiesUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleCapabilitiesRepositoryProtocol

    // MARK: - Init

    init(repository: ScheduleCapabilitiesRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute() async throws -> ScheduleCapabilities {
        try await repository.fetchCapabilities()
    }
}
