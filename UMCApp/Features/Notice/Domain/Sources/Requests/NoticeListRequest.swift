//
//  NoticeListRequest.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation
import UMCFoundation

public struct NoticeListRequest {
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
}
