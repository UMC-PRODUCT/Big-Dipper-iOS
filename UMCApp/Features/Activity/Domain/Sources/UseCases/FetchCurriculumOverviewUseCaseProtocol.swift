//
//  FetchCurriculumOverviewUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 7/29/26.
//

import Foundation

/// 스터디 커리큘럼 개요 조회 도메인 진입점
///
/// `ChallengerStudyView` 커리큘럼 섹션의 유일한 데이터 소스입니다.
/// 진행률(`CurriculumProgressModel`)과 주차별 미션(`[MissionCardModel]`)은 서버의 커리큘럼
/// 개요 응답 **하나**에서 함께 파생되므로, 진입점을 나누지 않고 한 번의 호출로
/// ``CurriculumOverview`` 를 반환합니다.
///
/// - Note: 레거시 `execute(weekNo:)` 는 주차별 상세 조회에 의존했으나 `CurriculumData`
///   정의 위치가 확정되지 않아 동결되었습니다. 본 진입점은 개요 조회만 사용하므로 `weekNo`
///   파라미터를 갖지 않으며, 주차별 상세 조회는 정의 위치 확정 후 후행 이슈에서 추가됩니다.
public protocol FetchCurriculumOverviewUseCaseProtocol {

    /// 커리큘럼 진행률과 주차별 미션을 한 번에 조회
    func execute() async throws -> CurriculumOverview
}
