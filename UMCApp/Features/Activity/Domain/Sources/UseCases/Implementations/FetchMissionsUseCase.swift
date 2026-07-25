//
//  FetchMissionsUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 7/15/26.
//

import Foundation

/// `FetchMissionsUseCaseProtocol` 의 기본 구현체
///
/// `StudyRepositoryProtocol.fetchMissions()` 에 위임하는 단순 조회 UseCase 입니다.
public final class FetchMissionsUseCase: FetchMissionsUseCaseProtocol {

    // MARK: - Property

    private let repository: StudyRepositoryProtocol

    // MARK: - Init

    public init(repository: StudyRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> [MissionCardModel] {
        try await repository.fetchMissions()
    }
}
