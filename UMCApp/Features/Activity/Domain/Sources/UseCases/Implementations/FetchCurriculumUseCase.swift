//
//  FetchCurriculumUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/8/26.
//

import Foundation

/// `FetchCurriculumUseCaseProtocol` 의 기본 구현체
///
/// `StudyRepositoryProtocol.fetchCurriculumProgress()` 에 위임하는 단순 조회 UseCase 입니다.
public final class FetchCurriculumUseCase: FetchCurriculumUseCaseProtocol {

    // MARK: - Property

    private let repository: StudyRepositoryProtocol

    // MARK: - Init

    public init(repository: StudyRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> CurriculumProgressModel {
        try await repository.fetchCurriculumProgress()
    }
}
