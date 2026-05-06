//
//  HomeUseCaseProvider.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

/// Home Feature에서 사용하는 UseCase들을 제공하는 Provider Protocol
protocol HomeUseCaseProviding {
    /// 내 프로필 조회 UseCase
    var fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol { get }
    /// 월별 일정 조회 UseCase
    var fetchSchedulesUseCase: FetchSchedulesUseCaseProtocol { get }
    /// 일정 상세 조회 UseCase
    var fetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol { get }
    /// 최근 공지 조회 UseCase
    var fetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol { get }
    /// FCM 토큰 등록 UseCase
    var registerFCMTokenUseCase: RegisterFCMTokenUseCaseProtocol { get }
    /// 일정 생성 UseCase
    var generateScheduleUseCase: GenerateScheduleUseCaseProtocol { get }
    /// 일정 수정 UseCase
    var updateScheduleUseCase: UpdateScheduleUseCaseProtocol { get }
    /// 일정 + 출석부 통합 삭제 UseCase
    var deleteScheduleUseCase: DeleteScheduleUseCaseProtocol { get }
    /// 일정 제목 기반 태그 분류 UseCase
    var classifyScheduleUseCase: ClassifyScheduleUseCase { get }
    /// 챌린저 검색 UseCase
    var searchChallengersUseCase: SearchChallengersUseCaseProtocol { get }
    /// 일정 생성/수정 권한 조회 UseCase
    var fetchScheduleCapabilitiesUseCase: FetchScheduleCapabilitiesUseCaseProtocol { get }
}

/// Home UseCase Provider 구현
///
/// HomeRepository, ChallengerGenRepository, ScheduleRepository를
/// 주입받아 UseCase들을 생성합니다.
final class HomeUseCaseProvider: HomeUseCaseProviding {

    // MARK: - Property

    let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    let fetchSchedulesUseCase: FetchSchedulesUseCaseProtocol
    let fetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol
    let fetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol
    let registerFCMTokenUseCase: RegisterFCMTokenUseCaseProtocol
    let generateScheduleUseCase: GenerateScheduleUseCaseProtocol
    let updateScheduleUseCase: UpdateScheduleUseCaseProtocol
    let deleteScheduleUseCase: DeleteScheduleUseCaseProtocol
    let classifyScheduleUseCase: ClassifyScheduleUseCase
    let searchChallengersUseCase: SearchChallengersUseCaseProtocol
    let fetchScheduleCapabilitiesUseCase: FetchScheduleCapabilitiesUseCaseProtocol

    // MARK: - Init

    init(
        homeRepository: HomeRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol,
        classifierRepository: ScheduleClassifierRepository,
        challengerSearchRepository: ChallengerSearchRepositoryProtocol,
        scheduleCapabilitiesRepository: ScheduleCapabilitiesRepositoryProtocol
    ) {
        self.fetchMyProfileUseCase = FetchMyProfileUseCase(
            repository: homeRepository
        )
        self.fetchSchedulesUseCase = FetchSchedulesUseCase(
            repository: homeRepository
        )
        self.fetchScheduleDetailUseCase = FetchScheduleDetailUseCase(
            repository: homeRepository
        )
        self.fetchRecentNoticesUseCase = FetchRecentNoticesUseCase(
            repository: homeRepository
        )
        self.registerFCMTokenUseCase = RegisterFCMTokenUseCase(
            repository: homeRepository
        )
        self.generateScheduleUseCase = GenerateScheduleUseCase(
            repository: scheduleRepository
        )
        self.updateScheduleUseCase = UpdateScheduleUseCase(
            repository: scheduleRepository
        )
        self.deleteScheduleUseCase = DeleteScheduleUseCase(
            repository: scheduleRepository
        )
        self.classifyScheduleUseCase = ClassifyScheduleUseCaseImpl(
            repository: classifierRepository
        )
        self.searchChallengersUseCase = SearchChallengersUseCase(
            repository: challengerSearchRepository
        )
        self.fetchScheduleCapabilitiesUseCase = FetchScheduleCapabilitiesUseCase(
            repository: scheduleCapabilitiesRepository
        )
    }
}
