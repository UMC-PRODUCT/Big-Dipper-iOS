//
//  StudyGroupScheduleCreateRequestDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation

/// 스터디 그룹 일정 연결 요청 DTO
///
/// `POST /api/v1/study-groups/schedules` body. 1단계 일정 생성으로 받은 `scheduleId` 를
/// 스터디 그룹·주차 커리큘럼에 연결합니다.
///
/// - Note: 모두 서버 응답 식별자이므로 전 레이어 `String` 으로 통일해 문자열로 직렬화합니다.
struct StudyGroupScheduleCreateRequestDTO: Encodable, Sendable {
    /// 연결할 일정 식별자 (1단계 생성 응답)
    let scheduleId: String
    /// 대상 스터디 그룹 식별자 (서버 응답)
    let studyGroupId: String
    /// 연결할 주차 커리큘럼 식별자 (서버 응답)
    let weeklyCurriculumId: String
}
