//
//  ChallengerStudyViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/26/26.
//

import ActivityDomain
import Foundation
import UMCFoundation

/// 챌린저(일반 참여자) 모드의 스터디/활동 섹션 ViewModel
///
/// `FetchCurriculumUseCaseProtocol` 을 통해 커리큘럼 진행 현황을 조회해
/// `ChallengerStudyView` 커리큘럼 섹션의 상태 소스로 사용됩니다.
///
/// - Note: 레거시는 `Loadable<CurriculumData>`(진행률 + 주차별 미션 카드)를 보유했으나,
///   주차별 미션 상세(`CurriculumData`)는 정의 위치 미확정으로 #749 에서 동결되어
///   본 진입점은 진행률(`CurriculumProgressModel`)만 보유합니다. 미션 카드 로딩과
///   스터디 제출 현황(#586)·커리큘럼 과제 제출(#587)은 백엔드 결선 후 후행 이슈에서
///   추가됩니다 (하단 TODO 참고).
@MainActor
@Observable
final class ChallengerStudyViewModel {

    // MARK: - Property

    private let fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol

    // MARK: - State

    private(set) var curriculumState: Loadable<CurriculumProgressModel> = .idle

    // MARK: - Init

    init(fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol) {
        self.fetchCurriculumUseCase = fetchCurriculumUseCase
    }

    // MARK: - Action

    /// 커리큘럼 진행 현황 로드
    ///
    /// 성공 시 `.loaded`, 이미 래핑된 `AppError` 는 그대로, 그 외 계층 에러는 대응
    /// `AppError` 로 매핑해 `.failed` 로 전이합니다. 모든 에러는 화면 내 인라인 표시용
    /// `Loadable.failed` 로 흐릅니다.
    func fetchCurriculum() async {
        curriculumState = .loading

        do {
            let progress = try await fetchCurriculumUseCase.execute()
            curriculumState = .loaded(progress)
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

    // MARK: - 미션/제출 현황 (백엔드 후행)

    // TODO: 주차별 미션 카드 결선 - [26.06.26] 이재원
    //  — 레거시 `CurriculumData`(진행률 + 미션 카드)가 의존하던 `fetchCurriculumData(weekNo:)`
    //    는 `CurriculumData` 정의 위치 미확정으로 #749 에서 동결됨. 정의 확정 후 미션 카드
    //    Loadable 상태와 주차 선택 로딩을 복원한다.
    // TODO: 스터디 제출 현황 조회(#586) 결선 - [26.06.26] 이재원
    //  — 백엔드 제출 현황 API 미제공으로 비활성화.
    // TODO: 커리큘럼 과제 제출(#587) 결선 - [26.06.26] 이재원
    //  — 백엔드 과제 제출 API 미제공으로 비활성화.
}
