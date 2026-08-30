//
//  CardExchangePageQueryDTO.swift
//  BusinessCardData
//
//  Created by JEONG on 8/30/26.
//

import Foundation

/// 명함첩 전량 조회 커서 쿼리 (`GET /api/v1/cards/exchanges`).
///
/// `cursor` 는 마지막으로 받은 `member_card_exchange.id`(exclusive)다. 서버가 `Long` 을
/// 문자열로 직렬화하므로 앱도 `String` 으로 왕복한다 (절대 규칙 #2).
/// `size` 는 Request 라 `Int` 그대로 둔다 (절대 규칙 #3 예외).
public struct CardExchangePageQueryDTO: Equatable, Sendable {

    // MARK: - Property

    public let cursor: String?
    /// 서버 최대치. 명함첩은 개인 수집 규모라 항상 최대로 받아 왕복을 줄인다.
    public let size: Int

    // MARK: - Init

    public init(cursor: String? = nil, size: Int = 100) {
        self.cursor = cursor
        self.size = size
    }

    // MARK: - Computed Property

    /// 첫 페이지는 `cursor` 키 **자체를 넣지 않는다** — 빈 문자열을 보내면 서버가 그것을
    /// 커서 값으로 파싱하려 든다.
    public var toParameters: [String: Any] {
        var parameters: [String: Any] = ["size": size]
        if let cursor, !cursor.isEmpty {
            parameters["cursor"] = cursor
        }
        return parameters
    }
}
