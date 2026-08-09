//
//  FetchScheduleCapabilitiesUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/9/26.
//

import Foundation

/// 일정 생성/수정 권한 조회 UseCase 구현체
public final class FetchScheduleCapabilitiesUseCase: FetchScheduleCapabilitiesUseCaseProtocol {

    // MARK: - Property

    private let repository: ScheduleCapabilitiesRepositoryProtocol

    // MARK: - Init

    public init(repository: ScheduleCapabilitiesRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> ScheduleCapabilities {
        try await repository.fetchCapabilities()
    }
}
