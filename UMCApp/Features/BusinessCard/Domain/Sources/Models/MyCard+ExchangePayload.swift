//
//  MyCard+ExchangePayload.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation
import UMCFoundation
import CoreNearbyExchange

// 매핑을 Domain이 소유한다 — Core가 피처 모델(MyCard)을 알면 역방향 의존이 된다.
public extension MyCard {

    /// 교환 전송용 페이로드로 변환한다.
    /// - Parameter cardID: 교환 세션 식별자. 기본은 새 UUID.
    func toExchangePayload(cardID: String = UUID().uuidString) throws -> ExchangePayload {
        try ExchangePayload(
            cardID: cardID,
            name: name,
            nickname: nickname,
            part: part.apiValue,
            generation: generation,
            university: university,
            email: email,
            github: github,
            linkedIn: linkedIn,
            blog: blog,
            avatarURL: avatarURL,
            cardLink: cardLink.urlString
        )
    }

    /// 수신 페이로드에서 명함을 복원한다.
    ///
    /// memberId는 `cardLink` 파싱으로만 복구한다 — 페이로드에서 정체성을 나르는 유일한 값이다.
    /// 파싱 불가한 part는 정본 매핑(`Profile.toProfileData`)과 같은 규칙으로 `.admin` 폴백.
    init(payload: ExchangePayload) {
        let linkedMemberId = URL(string: payload.cardLink).flatMap(CardLink.parse)?.memberId
        self.init(
            memberId: linkedMemberId ?? "",
            name: payload.name,
            nickname: payload.nickname,
            part: UMCPartType(apiValue: payload.part) ?? .admin,
            generation: payload.generation,
            university: payload.university,
            email: payload.email,
            github: payload.github,
            linkedIn: payload.linkedIn,
            blog: payload.blog,
            avatarURL: payload.avatarURL
        )
    }
}

public extension ReceivedCard {

    /// 수신 페이로드에서 명함첩 항목을 만든다. 교환 직후 저장 경로의 단일 진입점.
    init(payload: ExchangePayload, exchangeContext: String?, exchangedAt: Date = Date()) {
        self.init(
            id: payload.cardID,
            profile: MyCard(payload: payload),
            exchangedAt: exchangedAt,
            exchangeContext: exchangeContext,
            isConnected: false
        )
    }
}
