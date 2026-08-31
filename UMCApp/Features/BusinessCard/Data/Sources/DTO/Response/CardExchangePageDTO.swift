//
//  CardExchangePageDTO.swift
//  BusinessCardData
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import UMCFoundation

/// 명함첩 커서 페이지 (`CursorResponse<CardExchangeItemDTO>`).
///
/// 서버 공용 봉투(`content` / `nextCursor` / `hasNext`)를 그대로 받는다 —
/// `StudyGroupQueryController` 선례와 같은 형태라 신규 봉투가 아니다.
public struct CardExchangePageDTO: Codable, Equatable, Sendable {

    // MARK: - Property

    public let content: [CardExchangeItemDTO]
    /// 다음 페이지의 시작 커서(마지막 `member_card_exchange.id`). 마지막 페이지면 `nil`.
    public let nextCursor: String?
    public let hasNext: Bool

    // MARK: - Init

    public init(
        content: [CardExchangeItemDTO],
        nextCursor: String? = nil,
        hasNext: Bool = false
    ) {
        self.content = content
        self.nextCursor = nextCursor
        self.hasNext = hasNext
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case content, nextCursor, hasNext
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent([CardExchangeItemDTO].self, forKey: .content) ?? []
        nextCursor = try container.decodeFlexibleStringIfPresent(forKey: .nextCursor)
        hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(nextCursor, forKey: .nextCursor)
        try container.encode(hasNext, forKey: .hasNext)
    }
}
