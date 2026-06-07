//
//  FetchStudyMembersUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/8/26.
//

import Foundation

/// `FetchStudyMembersUseCaseProtocol` 의 기본 구현체
///
/// 스터디 그룹 상세 조회를 `StudyRepositoryProtocol` 에 위임하고, 응답의 멘토/스터디원을
/// 단일 목록으로 병합합니다. `groupId` 는 서버 String ID 로 전 레이어 통일됩니다.
public final class FetchStudyMembersUseCase: FetchStudyMembersUseCaseProtocol {

    // MARK: - Property

    private let repository: StudyRepositoryProtocol

    // MARK: - Init

    public init(repository: StudyRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func fetchStudyGroupMembers(
        groupId: String
    ) async throws -> [StudyGroupMember] {
        let detail = try await repository.fetchStudyGroupDetail(groupId: groupId)
        return detail.mentors + detail.members
    }
}
