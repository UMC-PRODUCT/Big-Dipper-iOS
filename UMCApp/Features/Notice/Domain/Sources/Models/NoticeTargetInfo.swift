//
//  NoticeTargetInfo.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation
import UMCFoundation

public struct NoticeTargetInfo {
    public let gisuId: String
    public let chapterId: String?
    public let schoolId: String?
    public let parts: [UMCPartType]?
    public let noticeTab: String?
    
    public init(gisuId: String, chapterId: String?, schoolId: String?, parts: [UMCPartType]?, noticeTab: String?) {
        self.gisuId = gisuId
        self.chapterId = chapterId
        self.schoolId = schoolId
        self.parts = parts
        self.noticeTab = noticeTab
    }
}
