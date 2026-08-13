//
//  CommunityThreadListUseCase.swift
//  CommunityDomain
//

import Foundation

public protocol CommunityThreadListUseCaseProtocol: Sendable {
    func loadThreads(
        filter: CommunityThreadFilter,
        query: String?,
        offset: Int
    ) async throws -> CommunityThreadPage

    func togglePin(threadId: String, isPinned: Bool) async throws
    func toggleMute(threadId: String, isMuted: Bool) async throws
    func leave(threadId: String) async throws

    /// 스와이프 삭제(#1134). 같은 REST 호출을 ``CommunityThreadEditUseCaseProtocol`` 도 갖지만,
    /// 화면마다 자기 UseCase 를 부르는 게 이 모듈의 기존 구성이라(`leave` 도 그렇다) 여기에도 둔다.
    func deleteThread(threadId: String) async throws
}

public struct CommunityThreadListUseCase: CommunityThreadListUseCaseProtocol {

    // MARK: - Property

    public static let pageSize = 20
    /// 서버가 받는 검색어 상한. 넘으면 잘라 보낸다 — 검색은 막을 만한 조작이 아니다.
    public static let queryMaxLength = 80

    private let repository: CommunityThreadRepositoryProtocol

    // MARK: - Init

    public init(repository: CommunityThreadRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func loadThreads(
        filter: CommunityThreadFilter,
        query: String?,
        offset: Int
    ) async throws -> CommunityThreadPage {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String?
        if let trimmed, !trimmed.isEmpty {
            normalized = String(
                trimmed.unicodeScalars.prefix(Self.queryMaxLength).map(Character.init)
            )
        } else {
            normalized = nil
        }

        return try await repository.fetchThreads(
            filter: filter.queryValue,
            query: normalized,
            offset: offset,
            limit: Self.pageSize
        )
    }

    public func togglePin(threadId: String, isPinned: Bool) async throws {
        try await repository.setPinned(threadId: threadId, isPinned: isPinned)
    }

    public func toggleMute(threadId: String, isMuted: Bool) async throws {
        try await repository.setMuted(threadId: threadId, isMuted: isMuted)
    }

    public func leave(threadId: String) async throws {
        try await repository.leaveThread(threadId: threadId)
    }

    public func deleteThread(threadId: String) async throws {
        try await repository.deleteThread(threadId: threadId)
    }
}
