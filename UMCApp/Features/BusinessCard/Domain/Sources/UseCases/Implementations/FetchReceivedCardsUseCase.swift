//
//  FetchReceivedCardsUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

public final class FetchReceivedCardsUseCase:
    FetchReceivedCardsUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let repository: ReceivedCardRepositoryProtocol

    // MARK: - Init

    public init(repository: ReceivedCardRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 공백만 입력된 검색어는 "검색 안 함"으로 취급한다 — 빈 결과 화면 대신 전체 목록.
    public func execute(query: String?) async throws -> [ReceivedCard] {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return try await repository.fetchAll()
        }
        return try await repository.search(query: trimmed)
    }
}
