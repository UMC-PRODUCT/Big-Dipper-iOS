//
//  NoticeReadStatusPage.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation

public struct NoticeReadStatusPage {
    public let users: [ReadStatusUser]
    public let nextCursor: String
    public let hasNext: Bool
    
    public init(users: [ReadStatusUser], nextCursor: String, hasNext: Bool) {
        self.users = users
        self.nextCursor = nextCursor
        self.hasNext = hasNext
    }
}
