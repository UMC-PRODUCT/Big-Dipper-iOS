//
//  FetchStudyMembersUseCase.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

// MARK: - FetchStudyMembersUseCase

/// 운영진 스터디원 관리 데이터 조회 UseCase 구현체
final class FetchStudyMembersUseCase: FetchStudyMembersUseCaseProtocol {

    // MARK: - Property

    private let repository: StudyRepositoryProtocol
    private let scheduleRepository: ScheduleRepositoryProtocol

    // MARK: - Init

    init(
        repository: StudyRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol
    ) {
        self.repository = repository
        self.scheduleRepository = scheduleRepository
    }

    // MARK: - Function

    func fetchMembers(
        week: Int,
        studyGroupId: Int?
    ) async throws -> [StudyMemberItem] {
        try await repository.fetchStudyMembers(
            week: week,
            studyGroupId: studyGroupId
        )
    }

    func fetchStudyGroups() async throws -> [StudyGroupItem] {
        try await repository.fetchStudyGroups()
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        try await repository.fetchStudyGroupDetails()
    }

    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        try await repository.fetchStudyGroupDetailsPage(
            cursor: cursor,
            size: size
        )
    }

    func fetchWeeks() async throws -> [Int] {
        try await repository.fetchWeeks()
    }

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        try await repository.fetchWeeklyCurriculumOptions()
    }

    func resolveChallengerId(
        memberId: Int,
        preferredGeneration: Int?
    ) async throws -> Int? {
        try await repository.resolveChallengerId(
            memberId: memberId,
            preferredGeneration: preferredGeneration
        )
    }

    func fetchWorkbookSubmissionURL(
        challengerWorkbookId: Int
    ) async throws -> String? {
        try await repository.fetchWorkbookSubmissionURL(
            challengerWorkbookId: challengerWorkbookId
        )
    }

    func reviewWorkbook(
        challengerWorkbookId: Int,
        isApproved: Bool,
        feedback: String
    ) async throws {
        try await repository.reviewWorkbook(
            challengerWorkbookId: challengerWorkbookId,
            isApproved: isApproved,
            feedback: feedback
        )
    }

    func selectBestWorkbook(
        challengerWorkbookId: Int,
        bestReason: String
    ) async throws {
        try await repository.selectBestWorkbook(
            challengerWorkbookId: challengerWorkbookId,
            bestReason: bestReason
        )
    }

    func createStudyGroup(
        gisuId: Int,
        name: String,
        part: UMCPartType,
        memberIds: [Int],
        mentorIds: [Int]
    ) async throws {
        try await repository.createStudyGroup(
            gisuId: gisuId,
            name: name,
            part: part,
            memberIds: memberIds,
            mentorIds: mentorIds
        )
    }

    func addStudyGroupMember(groupId: Int, memberId: Int) async throws {
        try await repository.addStudyGroupMember(groupId: groupId, memberId: memberId)
    }

    func removeStudyGroupMember(groupId: Int, memberId: Int) async throws {
        try await repository.removeStudyGroupMember(groupId: groupId, memberId: memberId)
    }

    func addStudyGroupMentor(groupId: Int, mentorId: Int) async throws {
        try await repository.addStudyGroupMentor(groupId: groupId, mentorId: mentorId)
    }

    func removeStudyGroupMentor(groupId: Int, mentorId: Int) async throws {
        try await repository.removeStudyGroupMentor(groupId: groupId, mentorId: mentorId)
    }

    func updateStudyGroup(
        groupId: Int,
        name: String
    ) async throws {
        try await repository.updateStudyGroup(
            groupId: groupId,
            name: name
        )
    }

    func deleteStudyGroup(groupId: Int) async throws {
        try await repository.deleteStudyGroup(groupId: groupId)
    }

    func createStudySchedule(
        request: GenerateScheduleRequetDTO
    ) async throws -> Int {
        try await scheduleRepository.generateSchedule(schedule: request)
    }

    func linkStudyGroupSchedule(
        scheduleId: Int,
        studyGroupId: Int,
        weeklyCurriculumId: Int
    ) async throws {
        try await repository.linkStudyGroupSchedule(
            scheduleId: scheduleId,
            studyGroupId: studyGroupId,
            weeklyCurriculumId: weeklyCurriculumId
        )
    }

    func deleteSchedule(scheduleId: Int) async throws {
        try await scheduleRepository.deleteSchedule(scheduleId: scheduleId)
    }

    func fetchStudyGroupMembers(groupId: Int) async throws -> [StudyGroupMember] {
        let detail = try await repository.fetchStudyGroupDetail(groupId: groupId)
        return detail.mentors + detail.members
    }
}
