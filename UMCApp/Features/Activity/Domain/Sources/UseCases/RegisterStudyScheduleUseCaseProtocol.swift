//
//  RegisterStudyScheduleUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import HomeDomain

/// 스터디 일정 등록 진입점
///
/// 등록은 서버 계약상 두 단계로 나뉜다.
/// 1. `POST /api/v2/schedules` 로 일반 일정을 만들고 `scheduleId` 를 받는다.
/// 2. 그 `scheduleId` 를 스터디 그룹·주차 커리큘럼에 연결한다.
///
/// 두 호출이 서로 다른 Repository 에 걸쳐 있어 호출부(ViewModel)가 조립을 떠안지 않도록
/// 단일 UseCase 로 묶는다. 2단계 실패 시 되돌리기는 ``deleteSchedule(scheduleId:)`` 로
/// 호출부가 정책(재시도/취소)에 맞춰 결정한다.
public protocol RegisterStudyScheduleUseCaseProtocol {

    /// 1단계 — 일정 생성
    ///
    /// - Returns: 생성된 일정 식별자 (서버 응답이므로 `String`)
    func createSchedule(_ request: ScheduleCreationRequest) async throws -> String

    /// 2단계 — 생성된 일정을 스터디 그룹·주차 커리큘럼에 연결
    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws

    /// 2단계 실패 후 1단계 일정을 되돌린다.
    func deleteSchedule(scheduleId: String) async throws
}
