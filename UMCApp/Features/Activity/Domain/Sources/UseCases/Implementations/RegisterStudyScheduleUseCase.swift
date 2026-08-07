//
//  RegisterStudyScheduleUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import HomeDomain

/// `RegisterStudyScheduleUseCaseProtocol` 의 기본 구현체
///
/// 일정 생성/삭제는 `HomeDomain` 의 canonical `ScheduleRepositoryProtocol` 에, 그룹 연결은
/// `StudyRepositoryProtocol` 에 위임한다. 두 Repository 를 조립하는 것 외에 자체 규칙은 없다.
public final class RegisterStudyScheduleUseCase: RegisterStudyScheduleUseCaseProtocol {

    // MARK: - Property

    private let scheduleRepository: ScheduleRepositoryProtocol
    private let studyRepository: StudyRepositoryProtocol

    // MARK: - Init

    public init(
        scheduleRepository: ScheduleRepositoryProtocol,
        studyRepository: StudyRepositoryProtocol
    ) {
        self.scheduleRepository = scheduleRepository
        self.studyRepository = studyRepository
    }

    // MARK: - Function

    public func createSchedule(_ request: ScheduleCreationRequest) async throws -> String {
        try await scheduleRepository.createSchedule(request)
    }

    public func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        try await studyRepository.linkStudyGroupSchedule(
            scheduleId: scheduleId,
            studyGroupId: studyGroupId,
            weeklyCurriculumId: weeklyCurriculumId
        )
    }

    public func deleteSchedule(scheduleId: String) async throws {
        try await scheduleRepository.deleteSchedule(scheduleId: scheduleId)
    }
}
