//
//  FetchCurriculumUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/8/26.
//

import Foundation

/// 스터디 커리큘럼 진행 현황 조회 도메인 진입점
///
/// `ChallengerStudyView` 커리큘럼 섹션의 데이터 소스입니다.
/// 한 파트의 커리큘럼 종료 진척도(`CurriculumProgressModel`)를 조회합니다.
///
/// - Note: 레거시 `execute(weekNo:) -> CurriculumData` 는 주차별 상세
///   (`fetchCurriculumData(weekNo:)`)에 의존했으나, `CurriculumData` 정의 위치
///   미확정으로 동결되었습니다. 본 진입점은 분리된
///   `StudyRepositoryProtocol.fetchCurriculumProgress()` 만 사용하므로
///   `weekNo` 파라미터를 갖지 않습니다. 주차별 상세 조회는 정의 위치 확정 후
///   후행 이슈에서 추가됩니다.
public protocol FetchCurriculumUseCaseProtocol {

    /// 커리큘럼 진행률 조회
    func execute() async throws -> CurriculumProgressModel
}
