//
//  ActivityCountDTO.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import UMCFoundation

// MARK: - Query

/// 스터디 카운트 쿼리. 커서 응답에 총개수가 없어 페이지를 크게 받아 항목 수를 센다.
/// size(50) 를 넘으면 `hasNext` 가 참으로 오고, 저장소가 그걸 읽어 `"50+"` 로 표기한다.
public struct StudyCountQueryDTO {
    public let size: Int

    public init(size: Int = 50) {
        self.size = size
    }

    public var toParameters: [String: Any] {
        ["size": size]
    }
}

/// 스크랩 카운트 쿼리 — totalElements만 필요하므로 최소 페이지(size 1)로 요청한다.
public struct ScrappedCountQueryDTO {
    public let page: Int
    public let size: Int

    public init(page: Int = 0, size: Int = 1) {
        self.page = page
        self.size = size
    }

    public var toParameters: [String: Any] {
        ["page": page, "size": size]
    }
}

// MARK: - Response

/// 스크랩 페이지 응답에서 totalElements만 취하는 얇은 DTO (절대규칙 #3 custom Codable).
struct ScrappedCountPageDTO: Codable {
    let totalElements: String

    private enum CodingKeys: String, CodingKey {
        case totalElements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalElements = try container.decodeFlexibleString(forKey: .totalElements)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalElements, forKey: .totalElements)
    }
}

/// 스터디 커서 페이지에서 항목 수만 세는 얇은 DTO.
/// 서버가 `cursor` 래핑 / `content` / `studyGroups` 어느 키로 응답해도 흡수한다
/// (Activity `MyStudyGroupsPageDTO`와 같은 유연 디코딩 — Bool도 문자열 흡수).
struct StudyCountPageDTO: Codable {
    let itemCount: Int
    let hasNext: Bool

    private struct AnyItemStub: Codable {}   // 항목 내용은 버리고 개수만 센다

    private enum CodingKeys: String, CodingKey {
        case cursor, content, studyGroups, hasNext
    }

    /// 중첩 DTO도 synthesized Codable 금지 (절대 규칙 #3) — hasNext는 서버가 "true"
    /// 문자열로 직렬화해도 흡수해야 하므로 `decodeBoolFlexibleIfPresent`를 쓴다
    /// (선례: Activity `MyStudyGroupsPageDTO`, 헬퍼: KeyedDecodingContainer+FlexibleNumber).
    private struct CursorEnvelope: Codable {
        let content: [AnyItemStub]?
        let studyGroups: [AnyItemStub]?
        let hasNext: Bool?

        private enum CodingKeys: String, CodingKey {
            case content, studyGroups, hasNext
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decodeIfPresent([AnyItemStub].self, forKey: .content)
            studyGroups = try container.decodeIfPresent([AnyItemStub].self, forKey: .studyGroups)
            hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(hasNext, forKey: .hasNext)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let cursor = try container.decodeIfPresent(CursorEnvelope.self, forKey: .cursor) {
            itemCount = (cursor.studyGroups ?? cursor.content ?? []).count
            hasNext = try cursor.hasNext
                ?? container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
        } else {
            let items = try container.decodeIfPresent([AnyItemStub].self, forKey: .studyGroups)
                ?? container.decodeIfPresent([AnyItemStub].self, forKey: .content)
                ?? []
            itemCount = items.count
            hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasNext, forKey: .hasNext)
    }
}
