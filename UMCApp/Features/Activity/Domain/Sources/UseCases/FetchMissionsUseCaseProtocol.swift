//
//  FetchMissionsUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 7/15/26.
//

import Foundation

/// 스터디 주차별 미션 카드 목록 조회 도메인 진입점
///
/// `ChallengerStudyView` 커리큘럼 섹션의 주차별 미션 타임라인 데이터 소스입니다.
/// `StudyRepositoryProtocol.fetchMissions()` 에 위임해 `[MissionCardModel]` 을 조회합니다.
///
/// - Note: 진행률(`CurriculumProgressModel`)은 별도 `FetchCurriculumUseCaseProtocol` 이
///   담당합니다. 서버가 진행률과 미션을 서로 다른 응답으로 주기 때문에 진입점을 둘로 나눴고,
///   `ChallengerStudyView` 가 두 상태를 각각 소비해 화면을 조립합니다.
public protocol FetchMissionsUseCaseProtocol {

    /// 주차별 미션 카드 목록 조회
    func execute() async throws -> [MissionCardModel]
}
