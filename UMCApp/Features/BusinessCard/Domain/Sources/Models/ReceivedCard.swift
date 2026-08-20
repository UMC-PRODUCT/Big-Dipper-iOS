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
    /// 교환 맥락 표시 문구 (예: "OT에서 교환").
    public let exchangeContext: String?
    /// 연결(친구) 상태. 서버 연동 전까지는 로컬 관리 값.
    public let isConnected: Bool

    // MARK: - Init

    public init(
        id: String,
        profile: MyCard,
        exchangedAt: Date,
        exchangeContext: String?,
        isConnected: Bool
    ) {
        self.id = id
        self.profile = profile
        self.exchangedAt = exchangedAt
        self.exchangeContext = exchangeContext
        self.isConnected = isConnected
    }
}
