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

    // MARK: - Init

    init(repository: StudyRepositoryProtocol) {
        self.repository = repository
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

    func createStudyGroupSchedule(
        name: String,
        startsAt: Date,
        endsAt: Date,
        isAllDay: Bool,
        locationName: String,
        latitude: Double,
        longitude: Double,
        description: String,
        studyGroupId: Int,
        gisuId: Int,
        requiresApproval: Bool
    ) async throws {
        try await repository.createStudyGroupSchedule(
            name: name,
            startsAt: startsAt,
            endsAt: endsAt,
            isAllDay: isAllDay,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            description: description,
            studyGroupId: studyGroupId,
            gisuId: gisuId,
            requiresApproval: requiresApproval
        )
    }
}
