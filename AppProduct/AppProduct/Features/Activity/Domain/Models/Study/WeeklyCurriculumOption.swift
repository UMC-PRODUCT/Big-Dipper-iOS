//
//  WeeklyCurriculumOption.swift
//  AppProduct
//
//  Created by jaewon Lee on 5/6/26.
//

import Foundation

/// 주차 커리큘럼 선택 옵션 도메인 모델
///
/// 스터디 그룹 일정을 특정 주차 커리큘럼과 연결할 때 (`POST /api/v1/study-groups/schedules`)
/// 사용자가 선택할 수 있는 주차 정보 한 줄을 표현합니다.
struct WeeklyCurriculumOption: Hashable, Identifiable, Sendable {

    let weeklyCurriculumId: Int
    let weekNo: Int
    let title: String

    var id: Int { weeklyCurriculumId }
}
