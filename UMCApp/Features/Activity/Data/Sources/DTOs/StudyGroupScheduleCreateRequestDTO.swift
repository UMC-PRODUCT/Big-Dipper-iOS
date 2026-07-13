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
/// - Note: 서버가 세 식별자를 정수로 받으므로 `Int` 로 보냅니다. 응답의 정수는 `String` 으로
///   다루지만 요청 본문은 정수 그대로 보내며, `String`→`Int` 변환은 ``StudyRepository`` 에서
///   이 DTO 를 만들 때 합니다.
struct StudyGroupScheduleCreateRequestDTO: Encodable, Sendable {
    /// 연결할 일정 식별자 (1단계 생성 응답)
    let scheduleId: Int
    /// 대상 스터디 그룹 식별자
    let studyGroupId: Int
    /// 연결할 주차 커리큘럼 식별자
    let weeklyCurriculumId: Int
}
