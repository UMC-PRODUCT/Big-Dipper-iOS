//
//  NoticeEditorTargetUseCase.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

/// 공지 에디터 타겟(지부/학교) 조회 UseCase 구현체
public final class NoticeEditorTargetUseCase: NoticeEditorTargetUseCaseProtocol {

    // MARK: - Property

    private let repository: NoticeEditorTargetRepositoryProtocol

    // MARK: - Init

    public init(repository: NoticeEditorTargetRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - NoticeEditorTargetUseCaseProtocol

    public func fetchAllBranches() async throws -> [NoticeTargetOption] {
        try await repository.fetchAllBranches()
    }

    public func fetchBranches(gisuId: String) async throws -> [NoticeTargetOption] {
        try await repository.fetchBranches(gisuId: gisuId)
    }

    public func fetchBranchName(chapterId: String) async throws -> String {
        try await repository.fetchBranchName(chapterId: chapterId)
    }

    public func fetchAllSchools() async throws -> [NoticeTargetOption] {
        try await repository.fetchAllSchools()
    }

    public func fetchSchools(gisuId: String) async throws -> [NoticeTargetOption] {
        try await repository.fetchSchools(gisuId: gisuId)
    }

    public func fetchSchools(inChapterId chapterId: String, gisuId: String) async throws -> [NoticeTargetOption] {
        try await repository.fetchSchools(inChapterId: chapterId, gisuId: gisuId)
    }
}
