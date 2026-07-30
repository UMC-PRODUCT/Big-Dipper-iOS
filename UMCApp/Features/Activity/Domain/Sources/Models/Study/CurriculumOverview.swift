//
//  CurriculumOverview.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 7/29/26.
//

import Foundation

/// 커리큘럼 개요 조회 결과
///
/// 서버는 커리큘럼 개요를 단일 응답으로 내려주며, 진행률과 주차별 미션이 모두 그 응답에서
/// 파생됩니다. 둘을 따로 조회하면 같은 엔드포인트를 두 번 호출하게 되므로, 한 번의 조회
/// 결과를 이 타입으로 묶어 전달합니다.
public struct CurriculumOverview: Equatable {

    // MARK: - Property

    /// 파트 커리큘럼의 종료 진척도
    public let progress: CurriculumProgressModel

    /// 주차 오름차순으로 정렬된 미션 카드 목록
    public let missions: [MissionCardModel]

    // MARK: - Initializer

    public init(
        progress: CurriculumProgressModel,
        missions: [MissionCardModel]
    ) {
        self.progress = progress
        self.missions = missions
    }
}
