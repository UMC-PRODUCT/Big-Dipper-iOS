//
//  NoticeListQuery.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain
import UMCFoundation

/// 공지 목록/검색 조회 Query DTO
///
///`GET /api/v1/notices`, `GET /api/v1/notices/search`

public struct NoticeListQuery: Encodable {
    public let gisuId: String
    public let chapterId: String?
    public let schoolId: String?
    public let part: UMCPartType?
    public let page: Int
    public let size: Int
    public let sort: [String]
    
    public init(
        gisuId: String,
        chapterId: String?,
        schoolId: String?,
        part: UMCPartType?,
        page: Int,
        size: Int,
        sort: [String]
    ) {
        self.gisuId = gisuId
        self.chapterId = chapterId
        self.schoolId = schoolId
        self.part = part
        self.page = page
        self.size = size
        self.sort = sort
    }
    
    public var toParameters: [String: Any] {
        var params: [String: Any] = [
            "gisuId": gisuId,
            "page": page,
            "size": size,
        ]
        if !sort.isEmpty {
            params["sort"] = sort
        }
        if let chapterId = chapterId {
            params["chapterId"] = chapterId
        }
        if let schoolId = schoolId {
            params["schoolId"] = schoolId
        }
        if let part = part {
            params["part"] = part.apiValue
        }
        return params
    }
}
