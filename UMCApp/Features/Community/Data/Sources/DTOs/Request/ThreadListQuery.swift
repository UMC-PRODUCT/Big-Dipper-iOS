//
//  ThreadListQuery.swift
//  CommunityData
//

import Foundation

/// `GET /api/v1/community/threads` 쿼리 파라미터.
///
/// - Important: `query` 가 `nil` 이면 `q` 키를 **아예 빼야 한다.** 빈 문자열을 보내면
///   서버가 검색 모드로 들어가 `pinned` 를 비우고 페이징 의미까지 달라진다.
public struct ThreadListQuery: Encodable {

    // MARK: - Property

    public let filter: String
    public let query: String?
    public let offset: Int
    public let limit: Int

    // MARK: - Init

    public init(filter: String, query: String?, offset: Int, limit: Int) {
        self.filter = filter
        self.query = query
        self.offset = offset
        self.limit = limit
    }

    // MARK: - Computed Property

    public var toParameters: [String: Any] {
        var parameters: [String: Any] = [
            "filter": filter,
            "offset": offset,
            "limit": limit
        ]
        if let query, !query.isEmpty {
            parameters["q"] = query
        }
        return parameters
    }
}
