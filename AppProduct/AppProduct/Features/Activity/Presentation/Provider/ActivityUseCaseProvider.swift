//
//  ActivityUseCaseProvider.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/25/26.
//

import Foundation

/// Activity Feature에서 사용하는 UseCase들을 제공하는 Provider Protocol
protocol ActivityUseCaseProviding {
    // MARK: - Session
    /// 세션 목록 조회 UseCase
    var fetchSessionsUseCase: FetchSessionsUseCaseProtocol { get }
    /// 현재 사용자 ID 조회 UseCase
    var fetchUserIdUseCase: FetchUserIdUseCaseProtocol { get }

    // MARK: - Attendance
    /// 챌린저 출석 관련 UseCase
    var challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol { get }
    /// 운영진 출석 관리 UseCase
    var operatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol { get }

    // MARK: - Schedule Classifier
    /// 일정 분류 UseCase
    var classifyScheduleUseCase: ClassifyScheduleUseCase { get }

    // MARK: - Study
    /// 커리큘럼 데이터 조회 UseCase
    var fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol { get }

    /// 운영진 스터디원 관리 UseCase
    var fetchStudyMembersUseCase: FetchStudyMembersUseCaseProtocol { get }
    
    // MARK: - Member
    /// 멤버 목록 조회 UseCase
    var fetchMembersUseCase: FetchMembersUseCaseProtocol { get }
}

/// Activity UseCase Provider 구현
///
/// RepositoryProvider와 Cross-Feature Repository를 주입받아 UseCase들을 생성합니다.
/// Activity Feature의 모든 UseCase를 중앙에서 관리합니다.
final class ActivityUseCaseProvider: ActivityUseCaseProviding {

    // MARK: - Property

    let fetchSessionsUseCase: FetchSessionsUseCaseProtocol
    let fetchUserIdUseCase: FetchUserIdUseCaseProtocol
    let challengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol
    let operatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol
    let classifyScheduleUseCase: ClassifyScheduleUseCase
    let fetchCurriculumUseCase: FetchCurriculumUseCaseProtocol
    let fetchStudyMembersUseCase: FetchStudyMembersUseCaseProtocol
    let fetchMembersUseCase: FetchMembersUseCaseProtocol

    // MARK: - Init

    init(
        repositoryProvider: ActivityRepositoryProviding,
        classifierRepository: ScheduleClassifierRepository
    ) {
        self.fetchSessionsUseCase = FetchSessionsUseCase(
            repository: repositoryProvider.activityRepository
        )
        self.fetchUserIdUseCase = FetchUserIdUseCase(
            repository: repositoryProvider.activityRepository
        )
        self.challengerAttendanceUseCase = ChallengerAttendanceUseCase(
            repository: repositoryProvider.challengerAttendanceRepository
        )
        self.operatorAttendanceUseCase = OperatorAttendanceUseCase(
            repository: repositoryProvider.operatorAttendanceRepository
        )
        self.classifyScheduleUseCase = ClassifyScheduleUseCaseImpl(
            repository: classifierRepository
        )
        self.fetchCurriculumUseCase = FetchCurriculumUseCase(
            repository: repositoryProvider.studyRepository
        )
        self.fetchStudyMembersUseCase = FetchStudyMembersUseCase(
            repository: repositoryProvider.studyRepository
        )
        self.fetchMembersUseCase = FetchMembersUseCase(
            repository: repositoryProvider.memberRepository
        )
    }
}
