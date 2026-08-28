//
//  UpdateExchangeContextUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/28/26.
//

import Foundation

public final class UpdateExchangeContextUseCase:
    UpdateExchangeContextUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let repository: ReceivedCardRepositoryProtocol

    // MARK: - Init

    public init(repository: ReceivedCardRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 공백만 남은 메모는 `nil` 로 지운다 — 빈 문자열을 저장하면 상세 화면이 「맥락 있음」
    /// 으로 읽어 빈 줄을 그린다.
    public func execute(card: ReceivedCard, context: String?) async throws -> ReceivedCard {
        let trimmed = context?.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = card.updatingExchangeContext(
            (trimmed?.isEmpty ?? true) ? nil : trimmed
        )
        try await repository.save(updated)
        return updated
    }
}
