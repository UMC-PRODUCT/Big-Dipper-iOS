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
/// 서버가 진행률과 미션을 서로 다른 응답으로 주므로 두 상태를 나눠 보유합니다.
/// `ChallengerStudyView` 가 두 Loadable 을 각각 소비해 화면을 조립합니다.
/// - `curriculumState`: `FetchCurriculumUseCaseProtocol` 로 조회한 진행률(`CurriculumProgressModel`)
/// - `missionsState`: `FetchMissionsUseCaseProtocol` 로 조회한 주차별 미션(`[MissionCardModel]`)
///
/// - Note: 스터디 제출 현황(#586)·커리큘럼 과제 제출(#587)은 백엔드 API 미제공으로
///   비활성화 상태이며 결선 후 후행 이슈에서 추가됩니다 (하단 TODO 참고).
@MainActor
@Observable
final class ChallengerStudyViewModel {

    // MARK: - Property

    private let fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol
    private let fetchMissionsUseCase: FetchMissionsUseCaseProtocol

    // MARK: - State

    private(set) var curriculumState: Loadable<CurriculumProgressModel> = .idle
    private(set) var missionsState: Loadable<[MissionCardModel]> = .idle

    // MARK: - Init

    init(
        fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol,
        fetchMissionsUseCase: FetchMissionsUseCaseProtocol
    ) {
        self.fetchCurriculumUseCase = fetchCurriculumUseCase
        self.fetchMissionsUseCase = fetchMissionsUseCase
    }

    // MARK: - Action

    /// 진행률과 미션을 병렬로 조회합니다. (초기 로드/재시도 공용 경로)
    ///
    /// 형제 ViewModel(`ChallengerAttendanceViewModel.refreshAfterForeground()`)의
    /// 병렬 갱신 house 패턴을 따릅니다.
    func load() async {
        async let curriculum: Void = fetchCurriculum()
        async let missions: Void = fetchMissions()
        _ = await (curriculum, missions)
    }

    /// 커리큘럼 진행 현황을 조회합니다.
    ///
    /// 이미 로딩 중이면 중복 호출을 무시합니다. `.task` 가 취소되면 던져지는 에러는
    /// 실패가 아니므로 이전 상태로 복원해 허위 에러 카드가 뜨지 않게 합니다. 에러 분기:
    /// - `CancellationError` / `NSURLErrorCancelled` → 이전 상태 복원
    /// - `AppError` → 그대로 `.failed` (이미 래핑됨)
    /// - `DomainError` / `NetworkError` / `RepositoryError` → 대응 `AppError` 로 매핑
    /// - 그 외 → `.failed(.unknown(message:))`
    func fetchCurriculum() async {
        if curriculumState.isLoading { return }

        let previousState = curriculumState
        curriculumState = .loading

        do {
            let progress = try await fetchCurriculumUseCase.execute()
            curriculumState = .loaded(progress)
        } catch is CancellationError {
            curriculumState = previousState
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            curriculumState = previousState
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

    /// 주차별 미션 카드 목록을 조회합니다.
    ///
    /// 취소/에러 처리 규칙은 `fetchCurriculum()` 과 동일한 house 패턴을 따릅니다
    /// (재진입 가드 + 취소 시 이전 상태 롤백).
    func fetchMissions() async {
        if missionsState.isLoading { return }

        let previousState = missionsState
        missionsState = .loading

        do {
            let missions = try await fetchMissionsUseCase.execute()
            missionsState = .loaded(missions)
        } catch is CancellationError {
            missionsState = previousState
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            missionsState = previousState
        } catch let error as AppError {
            missionsState = .failed(error)
        } catch let error as DomainError {
            missionsState = .failed(.domain(error))
        } catch let error as NetworkError {
            missionsState = .failed(.network(error))
        } catch let error as RepositoryError {
            missionsState = .failed(.repository(error))
        } catch {
            missionsState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }

    // MARK: - 제출 현황 (백엔드 후행)

    // TODO: 스터디 제출 현황 조회(#586) 결선 - [26.06.26] 이재원
    //  — 백엔드 제출 현황 API 미제공으로 비활성화.
    // TODO: 커리큘럼 과제 제출(#587) 결선 - [26.06.26] 이재원
    //  — 백엔드 과제 제출 API 미제공으로 비활성화.
}
