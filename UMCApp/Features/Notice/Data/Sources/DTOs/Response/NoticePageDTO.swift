//
//  NoticePageDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

/// 공지 목록/검색 전용 페이지 응답 DTO
///
/// 백엔드에서 숫자 필드를 문자열로 내려주는 스펙에 맞춰
/// page/size/totalElements/totalPages를 String으로 처리합니다.
public struct NoticePageDTO<T: Codable>: Codable {
    public let content: [T]
    public let page: String
    public let size: String
    public let totalElements: String
    public let totalPages: String
    public let hasNext: Bool
    public let hasPrevious: Bool?

    private enum CodingKeys: String, CodingKey {
        case content
        case page
        case size
        case totalElements
        case totalPages
        case hasNext
        case hasPrevious
    }

    /// 테스트/프리뷰용 멤버와이즈 이니셜라이저
    public init(
        content: [T],
        page: String,
        size: String,
        totalElements: String,
        totalPages: String,
        hasNext: Bool,
        hasPrevious: Bool?
    ) {
        self.content = content
        self.page = page
        self.size = size
        self.totalElements = totalElements
        self.totalPages = totalPages
        self.hasNext = hasNext
        self.hasPrevious = hasPrevious
    }

    /// 커스텀 디코더: 서버 응답의 페이징 메타데이터를 안전하게 파싱합니다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode([T].self, forKey: .content)
        self.page = try container.decode(String.self, forKey: .page)
        self.size = try container.decode(String.self, forKey: .size)
        self.totalElements = try container.decode(String.self, forKey: .totalElements)
        self.totalPages = try container.decode(String.self, forKey: .totalPages)
        self.hasNext = try container.decode(Bool.self, forKey: .hasNext)
        self.hasPrevious = try container.decodeIfPresent(Bool.self, forKey: .hasPrevious)
    }
}
