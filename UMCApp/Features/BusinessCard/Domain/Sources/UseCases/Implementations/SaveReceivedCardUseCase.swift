//
//  SaveReceivedCardUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation
import CoreNearbyExchange

public final class SaveReceivedCardUseCase:
    SaveReceivedCardUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let repository: ReceivedCardRepositoryProtocol

    // MARK: - Init

    public init(repository: ReceivedCardRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 교환·QR 스캔 어느 경로로 들어와도 같은 변환을 거치게 하는 단일 저장 진입점.
    public func execute(
        payload: ExchangePayload,
        exchangeContext: String?
    ) async throws -> ReceivedCard {
        let card = ReceivedCard(payload: payload, exchangeContext: exchangeContext)
        try await repository.save(card)
        return card
    }

    /// 딥링크 경로 — 서버 조회로 이미 복원된 명함을 그대로 저장한다.
    public func execute(
        card: MyCard,
        cardID: String,
        exchangeContext: String?
    ) async throws -> ReceivedCard {
        let received = ReceivedCard(
            id: cardID,
            profile: card,
            exchangedAt: Date(),
            exchangeContext: exchangeContext,
            isConnected: false
        )
        try await repository.save(received)
        return received
    }
}
