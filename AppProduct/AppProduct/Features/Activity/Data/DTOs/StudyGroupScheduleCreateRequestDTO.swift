//
//  StudyGroupScheduleCreateRequestDTO.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/24/26.
//

import Foundation

/// 스터디 그룹 일정 연결 Request DTO (V2 2단계 호출)
///
/// `POST /api/v1/study-groups/schedules`
///
/// 1단계 V2 일정 생성(`POST /api/v2/schedules`)으로 받아온 `scheduleId`를
/// 스터디 그룹과 주차 커리큘럼에 연결합니다.
struct StudyGroupScheduleCreateRequestDTO: Encodable, Equatable {
    let scheduleId: Int
    let studyGroupId: Int
    let weeklyCurriculumId: Int
}
