//
//  FetchCurriculumUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import Foundation

// MARK: - FetchCurriculumUseCase

/// 커리큘럼 데이터 조회 UseCase 구현체
final class FetchCurriculumUseCase: FetchCurriculumUseCaseProtocol {

    // MARK: - Property

    private let repository: StudyRepositoryProtocol

    // MARK: - Init

    init(repository: StudyRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    func execute(weekNo: Int?) async throws -> CurriculumData {
        try await repository.fetchCurriculumData(weekNo: weekNo)
    }
}
