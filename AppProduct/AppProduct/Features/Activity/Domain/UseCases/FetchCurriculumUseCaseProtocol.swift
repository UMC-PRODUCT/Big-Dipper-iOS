//
//  FetchCurriculumUseCaseProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import Foundation

// MARK: - Protocol

protocol FetchCurriculumUseCaseProtocol {
    /// 커리큘럼 데이터 조회 (진행률 + 미션 목록)
    /// - Parameter weekNo: 조회할 특정 주차 번호. nil이면 전체 주차를 반환합니다.
    func execute(weekNo: Int?) async throws -> CurriculumData
}
