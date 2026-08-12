//
//  ThreadMessageQuery.swift
//  CommunityData
//

import Foundation

/// `GET /api/v1/community/threads/{threadId}/messages` 쿼리 파라미터.
///
/// `before` 는 **배타적** 커서다. `nil` 이면 최신부터 `limit` 개를 받는다.
public struct ThreadMessageQuery: Encodable {

    // MARK: - Property

    public let before: String?
    public let limit: Int

    // MARK: - Init

    public init(before: String?, limit: Int) {
        self.before = before
        self.limit = limit
    }

    // MARK: - Computed Property

    public var toParameters: [String: Any] {
        var parameters: [String: Any] = ["limit": limit]
        if let before, !before.isEmpty {
            parameters["before"] = before
        }
        return parameters
    }
}
