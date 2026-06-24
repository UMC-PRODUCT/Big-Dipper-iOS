//
//  NoticePage.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation

public struct NoticePage {
    public let items: [NoticeItemModel]
    public let hasNext: Bool
    public let totalElements: String
    
    public init(items: [NoticeItemModel], hasNext: Bool, totalElements: String) {
        self.items = items
        self.hasNext = hasNext
        self.totalElements = totalElements
    }
}
