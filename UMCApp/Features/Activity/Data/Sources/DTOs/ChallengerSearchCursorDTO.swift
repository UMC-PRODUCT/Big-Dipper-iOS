//
//  ChallengerSearchCursorDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import UMCFoundation

// MARK: - ChallengerSearchCursorResultDTO

/// 챌린저 커서 검색 결과 DTO
///
/// `GET /api/v1/challenger/search/cursor`
///
/// 서버 응답은 `{ "cursor": { ... }, "partCounts": [ ... ] }` 형태입니다. `partCounts` 는
/// 파트별 집계 UI 가 이식되기 전까지 소비처가 없어 디코딩하지 않습니다 — 쓰지 않는 필드를
/// 실어 두면 서버 계약이 바뀌었을 때 검색 자체가 깨질 위험만 늘어납니다.
struct ChallengerSearchCursorResultDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let cursor: ChallengerSearchCursorPageDTO

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case cursor
    }

    // MARK: - Init

    init(cursor: ChallengerSearchCursorPageDTO) {
        self.cursor = cursor
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cursor = try container.decodeIfPresent(
            ChallengerSearchCursorPageDTO.self,
            forKey: .cursor
        ) ?? .empty
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cursor, forKey: .cursor)
    }
}

// MARK: - ChallengerSearchCursorPageDTO

/// 커서 페이지 메타 + 항목 목록
///
/// 항목 타입은 오프셋 검색과 동일한 서버 `SearchChallengerItemResponse` 라
/// ``ChallengerSearchOffsetItemDTO`` 를 그대로 재사용합니다(중복 DTO 선언 금지).
struct ChallengerSearchCursorPageDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let content: [ChallengerSearchOffsetItemDTO]

    /// 다음 페이지 커서. 서버가 `Long` 으로 내려주는 페이지네이션 토큰이라 `Int?` 입니다.
    let nextCursor: Int?

    let hasNext: Bool

    // MARK: - Empty

    /// `cursor` 필드 부재 시 사용할 빈 페이지.
    static let empty = ChallengerSearchCursorPageDTO(
        content: [],
        nextCursor: nil,
        hasNext: false
    )

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case content
        case nextCursor
        case hasNext
    }

    // MARK: - Init

    init(
        content: [ChallengerSearchOffsetItemDTO],
        nextCursor: Int?,
        hasNext: Bool
    ) {
        self.content = content
        self.nextCursor = nextCursor
        self.hasNext = hasNext
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent(
            [ChallengerSearchOffsetItemDTO].self,
            forKey: .content
        ) ?? []
        nextCursor = try container.decodeIntFlexibleIfPresent(forKey: .nextCursor)
        hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(nextCursor, forKey: .nextCursor)
        try container.encode(hasNext, forKey: .hasNext)
    }
}
