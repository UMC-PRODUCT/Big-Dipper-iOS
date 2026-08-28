//
//  ReceivedCard.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 교환으로 받은 명함 한 장 (명함첩 항목, MP-F05).
public struct ReceivedCard: Identifiable, Equatable, Hashable, Sendable {

    // MARK: - Property

    /// 교환 페이로드의 cardID. 같은 상대와 재교환 시 upsert 키.
    public let id: String
    public let profile: MyCard
    public let exchangedAt: Date
    /// 사용자가 적는 교환 맥락 메모 (예: "OT에서 교환"). 장소·자리는 앱이 알 수 없어
    /// 상세 화면에서 직접 남긴다 (#1227).
    public let exchangeContext: String?
    /// 받은 경로. 앱이 아는 값이라 저장 시점에 자동으로 채운다.
    public let exchangeMethod: ExchangeMethod

    // MARK: - Init

    public init(
        id: String,
        profile: MyCard,
        exchangedAt: Date,
        exchangeContext: String?,
        exchangeMethod: ExchangeMethod = .unknown
    ) {
        self.id = id
        self.profile = profile
        self.exchangedAt = exchangedAt
        self.exchangeContext = exchangeContext
        self.exchangeMethod = exchangeMethod
    }

    // MARK: - Function

    /// 맥락 메모만 바꾼 사본. 상세 화면 편집이 교환 시각·프로필을 건드리지 않게 한다.
    public func updatingExchangeContext(_ context: String?) -> ReceivedCard {
        ReceivedCard(
            id: id,
            profile: profile,
            exchangedAt: exchangedAt,
            exchangeContext: context,
            exchangeMethod: exchangeMethod
        )
    }
}
