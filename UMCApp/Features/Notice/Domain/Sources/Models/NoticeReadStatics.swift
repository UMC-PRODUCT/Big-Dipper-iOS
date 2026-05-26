//
//  NoticeReadStatics.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation

public struct NoticeReadStatics {
    public let totalCount: String
    public let readCount: String
    public let unreadCount: String
    public let readRate: String
    
    public init(totalCount: String, readCount: String, unreadCount: String, readRate: String) {
        self.totalCount = totalCount
        self.readCount = readCount
        self.unreadCount = unreadCount
        self.readRate = readRate
    }
}
