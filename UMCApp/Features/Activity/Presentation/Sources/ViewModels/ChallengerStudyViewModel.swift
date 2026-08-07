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
/// 진행률과 미션은 서버의 커리큘럼 개요 응답 하나에서 함께 내려오므로 조회는 단일
/// `FetchCurriculumOverviewUseCaseProtocol` 로 수행하고, 그 결과를 두 상태에 나눠 담습니다.
/// - `curriculumState`: 진행률(`CurriculumProgressModel`)
/// - `missionsState`: 주차별 미션(`[MissionCardModel]`)
///
/// 상태를 둘로 나눠 두는 이유는 `ChallengerStudyView` 가 둘을 다르게 소비하기 때문입니다
/// (미션이 비면 진행률 대신 안내 가이드를 노출). 제출 현황(#586)·과제 제출(#587)이 결선되면
/// 미션은 별도 응답에서 파생돼 진행률과 갈라지므로, 그때 조회 경로만 분리하면 됩니다.
///
/// - Note: 제출 현황 API(`WORKBOOK-104`)는 **운영진 스코프**(요청자가 관리할 수 있는 그룹의
///   스터디원 목록)로 결선돼 운영진 화면에만 쓰입니다. 챌린저 본인 시점의 제출 현황(#586)은
///   워크북 단건 조회(`WORKBOOK-102`)를 써야 하는데 그 화면이 아직 미이식이라 여전히
///   비활성화 상태입니다. 과제 제출(#587)도 대상 API가 없습니다 (하단 TODO 참고).
@MainActor
@Observable
final class ChallengerStudyViewModel {

    // MARK: - Property

    private let fetchCurriculumOverviewUseCase: FetchCurriculumOverviewUseCaseProtocol

    // MARK: - State

    private(set) var curriculumState: Loadable<CurriculumProgressModel> = .idle
    private(set) var missionsState: Loadable<[MissionCardModel]> = .idle

    // MARK: - Computed Property

    /// 커리큘럼 개요 조회가 진행 중인지 여부.
    ///
    /// `load()` 의 재진입 가드와 재시도 버튼의 로딩 피드백이 함께 사용합니다.
    var isLoading: Bool {
        curriculumState.isLoading || missionsState.isLoading
    }

    // MARK: - Init

    init(fetchCurriculumOverviewUseCase: FetchCurriculumOverviewUseCaseProtocol) {
        self.fetchCurriculumOverviewUseCase = fetchCurriculumOverviewUseCase
    }

    // MARK: - Action

    /// 커리큘럼 개요를 조회해 진행률과 미션 상태를 함께 채웁니다. (초기 로드/재시도 공용 경로)
    ///
    /// 이미 로딩 중이면 중복 호출을 무시합니다. `.task` 가 취소되면 던져지는 에러는
    /// 실패가 아니므로 이전 상태로 복원해 허위 에러 카드가 뜨지 않게 합니다. 에러 분기:
    /// - `CancellationError` / `NSURLErrorCancelled` → 이전 상태 복원
    /// - `AppError` → 그대로 `.failed` (이미 래핑됨)
    /// - `DomainError` / `NetworkError` / `RepositoryError` → 대응 `AppError` 로 매핑
    /// - 그 외 → `.failed(.unknown(message:))`
    func load() async {
        if isLoading { return }

        let previousCurriculum = curriculumState
        let previousMissions = missionsState
        curriculumState = .loading
        missionsState = .loading

        do {
            let overview = try await fetchCurriculumOverviewUseCase.execute()
            curriculumState = .loaded(overview.progress)
            missionsState = .loaded(overview.missions)
        } catch is CancellationError {
            curriculumState = previousCurriculum
            missionsState = previousMissions
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            curriculumState = previousCurriculum
            missionsState = previousMissions
        } catch let error as AppError {
            markFailed(error)
        } catch let error as DomainError {
            markFailed(.domain(error))
        } catch let error as NetworkError {
            markFailed(.network(error))
        } catch let error as RepositoryError {
            markFailed(.repository(error))
        } catch {
            markFailed(.unknown(message: error.localizedDescription))
        }
    }

    // MARK: - Function

    /// 단일 조회가 실패했으므로 두 상태를 같은 에러로 함께 전이시킵니다.
    private func markFailed(_ error: AppError) {
        curriculumState = .failed(error)
        missionsState = .failed(error)
    }

    // MARK: - 제출 현황 (백엔드 후행)

    // TODO: 스터디 제출 현황 조회(#586) 결선 - [26.06.26] 이재원
    //  — 운영진 목록(WORKBOOK-104)은 결선됐으나 챌린저 본인 시점은 워크북 단건
    //    조회(WORKBOOK-102)가 필요하고 그 화면이 미이식이라 비활성화 유지.
    // TODO: 커리큘럼 과제 제출(#587) 결선 - [26.06.26] 이재원
    //  — 백엔드 과제 제출 API 미제공으로 비활성화.
}
