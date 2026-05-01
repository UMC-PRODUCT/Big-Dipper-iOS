//
//  ChallengerStudyViewModel.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import Foundation
import SwiftUI

// MARK: - CurriculumData

/// 커리큘럼 화면에 필요한 데이터 모델
struct CurriculumData: Equatable {
    var progress: CurriculumProgressModel
    var missions: [MissionCardModel]
}

// MARK: - ChallengerStudyViewModel

/// Challenger 모드의 스터디/활동 섹션 ViewModel
///
/// UseCase를 통해 커리큘럼 데이터를 조회하고 미션을 제출합니다.
@Observable
final class ChallengerStudyViewModel {

    // MARK: - Dependency

    private let fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol
    private let errorHandler: ErrorHandler

    // MARK: - State

    private(set) var curriculumState: Loadable<CurriculumData> = .idle

    // MARK: - Init

    init(
        fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self.fetchCurriculumUseCase = fetchCurriculumUseCase
        self.errorHandler = errorHandler
    }

    // MARK: - Action

    /// 커리큘럼 데이터 로드
    /// - Parameter weekNo: 조회할 특정 주차 번호. nil이면 전체 주차를 반환합니다.
    @MainActor
    func fetchCurriculum(weekNo: Int? = nil) async {
        curriculumState = .loading

        do {
            let data = try await fetchCurriculumUseCase.execute(weekNo: weekNo)
            curriculumState = .loaded(data)
        } catch let error as AppError {
            curriculumState = .failed(error)
        } catch let error as DomainError {
            curriculumState = .failed(.domain(error))
        } catch let error as NetworkError {
            curriculumState = .failed(.network(error))
        } catch let error as RepositoryError {
            curriculumState = .failed(.repository(error))
        } catch {
            curriculumState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }

}
