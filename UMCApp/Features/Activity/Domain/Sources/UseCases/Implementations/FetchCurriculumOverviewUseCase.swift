//
//  FetchCurriculumOverviewUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 7/29/26.
//

import Foundation

/// `FetchCurriculumOverviewUseCaseProtocol` 의 기본 구현체
///
/// `StudyRepositoryProtocol.fetchCurriculumOverview()` 에 위임하는 단순 조회 UseCase 입니다.
public final class FetchCurriculumOverviewUseCase: FetchCurriculumOverviewUseCaseProtocol {

    // MARK: - Property

    private let repository: StudyRepositoryProtocol

    // MARK: - Init

    public init(repository: StudyRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> CurriculumOverview {
        try await repository.fetchCurriculumOverview()
    }
}
