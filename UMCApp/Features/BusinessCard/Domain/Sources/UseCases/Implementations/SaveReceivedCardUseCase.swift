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
    ///
    /// 저장 직전에 ``MyCard/validate()``로 한 번 더 거른다. 서버 조회 경로는 이미 변환에서
    /// 걸리지만, 근거리 교환은 상대 기기가 준 값을 그대로 싣는다 — v1 페이로드는 기수·파트
    /// 필드 자체가 없어 「운영진 · 기수 없음」 명함이 명함첩에 남을 수 있었다 (#1223).
    public func execute(
        payload: ExchangePayload,
        ownerMemberId: String,
        exchangeContext: String?,
        exchangeMethod: ExchangeMethod
    ) async throws -> ReceivedCard? {
        let card = ReceivedCard(
            payload: payload,
            exchangeContext: exchangeContext,
            exchangeMethod: exchangeMethod
        )
        guard !isOwn(memberId: card.profile.memberId, ownerMemberId: ownerMemberId) else {
            return nil
        }
        try card.profile.validate()
        try await repository.save(card)
        return card
    }

    /// 딥링크 경로 — 서버 조회로 이미 복원된 명함을 그대로 저장한다.
    public func execute(
        card: MyCard,
        cardID: String,
        ownerMemberId: String,
        exchangeContext: String?,
        exchangeMethod: ExchangeMethod
    ) async throws -> ReceivedCard? {
        guard !isOwn(memberId: card.memberId, ownerMemberId: ownerMemberId) else { return nil }
        try card.validate()

        let received = ReceivedCard(
            id: cardID,
            profile: card,
            exchangedAt: Date(),
            exchangeContext: exchangeContext,
            exchangeMethod: exchangeMethod
        )
        try await repository.save(received)
        return received
    }

    // MARK: - Private Function

    /// 빈 id 끼리는 비교하지 않는다. `cardLink` 를 못 읽으면 `memberId` 가 빈 문자열이 되는데,
    /// 그때 내 id 까지 비어 있으면 **모르는 상대를 나 자신으로 오인해 통째로 버린다.**
    private func isOwn(memberId: String, ownerMemberId: String) -> Bool {
        !memberId.isEmpty && memberId == ownerMemberId
    }
}
