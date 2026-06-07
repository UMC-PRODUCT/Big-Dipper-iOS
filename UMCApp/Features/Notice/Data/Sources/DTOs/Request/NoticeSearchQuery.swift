//
//  NoticeSearchQuery.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain
import UMCFoundation

/// 공지사항 검색 Query DTO
///
/// `GET /api/v1/notices/search`
public struct NoticeSearchQuery {

    // MARK: - Property

    /// 검색 키워드
    public let keyword: String
    /// 기수 ID
    public let gisuId: String
    /// 지부 ID
    public let chapterId: String?
    /// 학교 ID
    public let schoolId: String?
    /// 파트
    public let part: UMCPartType?
    /// 페이지 번호
    public let page: Int
    /// 페이지 크기
    public let size: Int
    /// 정렬 기준
    public let sort: [String]

    // MARK: - Init

    public init(
        keyword: String,
        gisuId: String,
        chapterId: String?,
        schoolId: String?,
        part: UMCPartType?,
        page: Int,
        size: Int,
        sort: [String]
    ) {
        self.keyword = keyword
        self.gisuId = gisuId
        self.chapterId = chapterId
        self.schoolId = schoolId
        self.part = part
        self.page = page
        self.size = size
        self.sort = sort
    }

    /// Query Parameter Dictionary 변환
    public var toParameters: [String: Any] {
        var params: [String: Any] = [
            "keyword": keyword,
            "gisuId": gisuId,
            "page": page,
            "size": size
        ]
        if !sort.isEmpty {
            params["sort"] = sort
        }
        if let chapterId {
            params["chapterId"] = chapterId
        }
        if let schoolId {
            params["schoolId"] = schoolId
        }
        if let part {
            params["part"] = part.apiValue
        }
        return params
    }
}
