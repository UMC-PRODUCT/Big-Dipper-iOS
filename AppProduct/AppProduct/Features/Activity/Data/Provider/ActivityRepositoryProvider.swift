//
//  ActivityRepositoryProvider.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/27/26.
//

import Foundation

/// Activity Feature에서 사용하는 Repository들을 제공하는 Provider Protocol
protocol ActivityRepositoryProviding {
    /// 챌린저 출석 데이터 접근 Repository
    var challengerAttendanceRepository: ChallengerAttendanceRepositoryProtocol { get }
    /// 운영진 출석 관리 Repository
    var operatorAttendanceRepository: OperatorAttendanceRepositoryProtocol { get }
    /// Activity 통합 데이터 접근 Repository
    var activityRepository: ActivityRepositoryProtocol { get }
    /// Study 데이터 접근 Repository
    var studyRepository: StudyRepositoryProtocol { get }
    /// 멤버 목록 데이터 접근 Repository
    var memberRepository: MemberRepositoryProtocol { get }
}

/// Activity Repository Provider 구현
///
/// Activity Feature 전용 Repository들을 중앙에서 관리합니다.
/// Mock/Real 구현체 교체 시 이 Provider만 수정하면 됩니다.
final class ActivityRepositoryProvider: ActivityRepositoryProviding {

    // MARK: - Property

    let challengerAttendanceRepository: ChallengerAttendanceRepositoryProtocol
    let operatorAttendanceRepository: OperatorAttendanceRepositoryProtocol
    let activityRepository: ActivityRepositoryProtocol
    let studyRepository: StudyRepositoryProtocol
    let memberRepository: MemberRepositoryProtocol

    // MARK: - Init

    init(
        challengerAttendanceRepository: ChallengerAttendanceRepositoryProtocol,
        operatorAttendanceRepository: OperatorAttendanceRepositoryProtocol,
        activityRepository: ActivityRepositoryProtocol,
        studyRepository: StudyRepositoryProtocol,
        memberRepository: MemberRepositoryProtocol
    ) {
        self.challengerAttendanceRepository = challengerAttendanceRepository
        self.operatorAttendanceRepository = operatorAttendanceRepository
        self.activityRepository = activityRepository
        self.studyRepository = studyRepository
        self.memberRepository = memberRepository
    }
}

// MARK: - Factory

extension ActivityRepositoryProvider {
    /// Mock Repository들로 구성된 Provider 생성
    static func mock() -> ActivityRepositoryProvider {
        ActivityRepositoryProvider(
            challengerAttendanceRepository: MockAttendanceRepository(),
            operatorAttendanceRepository: MockAttendanceRepository(),
            activityRepository: MockActivityRepository(),
            studyRepository: MockStudyRepository(),
            memberRepository: MockMemberRepository()
        )
    }

    /// 실제 API 연결 Provider 생성
    ///
    /// 출석 Repository만 실제 구현체, 나머지는 Mock 유지
    static func real(
        adapter: MoyaNetworkAdapter,
        homeRepository: HomeRepositoryProtocol
    ) -> ActivityRepositoryProvider {
        let attendanceRepo = AttendanceRepository(adapter: adapter)
        let activityRepository = ActivityRepository(
            attendanceRepository: attendanceRepo
        )
        let studyRepository = StudyRepository(adapter: adapter)
        let memberRepository = MemberRepository(
            adapter: adapter,
            studyRepository: studyRepository
        )
        return ActivityRepositoryProvider(
            challengerAttendanceRepository: attendanceRepo,
            operatorAttendanceRepository: attendanceRepo,
            activityRepository: activityRepository,
            studyRepository: studyRepository,
            memberRepository: memberRepository
        )
    }
}
