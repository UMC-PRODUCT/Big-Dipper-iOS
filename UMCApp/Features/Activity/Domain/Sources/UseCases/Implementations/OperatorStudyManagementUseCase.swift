//
//  OperatorStudyManagementUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/27/26.
//

import Foundation
import UMCFoundation

/// `OperatorStudyManagementUseCaseProtocol` 의 기본 구현체
///
/// 운영진 스터디 관리 액션을 모두 `StudyRepositoryProtocol` 에 그대로 위임합니다.
/// 커서·기수를 포함한 모든 식별자를 `String` 으로 전달하며(전 레이어 `String` 통일),
/// `Int` 변환은 Repository 가 실제 비교/직렬화하는 연산 시점에만 수행합니다.
public final class OperatorStudyManagementUseCase: OperatorStudyManagementUseCaseProtocol {

    // MARK: - Property

    private let repository: StudyRepositoryProtocol

    // MARK: - Init

    public init(repository: StudyRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - 조회 / 페이지네이션

    public func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        try await repository.fetchStudyGroupDetailsPage(
            cursor: cursor,
            size: size
        )
    }

    public func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        try await repository.resolveChallengerId(
            memberId: memberId,
            preferredGeneration: preferredGeneration
        )
    }

    // MARK: - 제출 현황

    public func fetchStudyGroupNames() async throws -> [StudyGroupName] {
        try await repository.fetchStudyGroupNames()
    }

    public func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage {
        try await repository.fetchStudyMemberSubmissions(
            studyGroupId: studyGroupId,
            weekNos: weekNos,
            cursor: cursor,
            size: size
        )
    }

    // MARK: - 그룹 CRUD

    public func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        try await repository.createStudyGroup(
            gisuId: gisuId,
            name: name,
            part: part,
            memberIds: memberIds,
            mentorIds: mentorIds
        )
    }

    public func updateStudyGroup(groupId: String, name: String) async throws {
        try await repository.updateStudyGroup(groupId: groupId, name: name)
    }

    public func deleteStudyGroup(groupId: String) async throws {
        try await repository.deleteStudyGroup(groupId: groupId)
    }

    // MARK: - 멤버 / 멘토

    public func addStudyGroupMember(groupId: String, memberId: String) async throws {
        try await repository.addStudyGroupMember(groupId: groupId, memberId: memberId)
    }

    public func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        try await repository.removeStudyGroupMember(groupId: groupId, memberId: memberId)
    }

    public func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        try await repository.addStudyGroupMentor(groupId: groupId, mentorId: mentorId)
    }

    public func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        try await repository.removeStudyGroupMentor(groupId: groupId, mentorId: mentorId)
    }
}
