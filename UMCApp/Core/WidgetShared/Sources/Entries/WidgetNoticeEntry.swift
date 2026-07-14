//
//  WidgetNoticeEntry.swift
//  CoreWidgetShared
//
//  Created by euijjang97 on 4/23/26.
//

import WidgetKit
import Foundation

public struct WidgetNoticeEntry: TimelineEntry {

    // MARK: - Property

    public let date: Date
    public let noticeTitle: String
    public let noticeBody: String
    public let postedAt: Date?

    // MARK: - Init

    public init(
        date: Date,
        noticeTitle: String,
        noticeBody: String,
        postedAt: Date? = nil
    ) {
        self.date = date
        self.noticeTitle = noticeTitle
        self.noticeBody = noticeBody
        self.postedAt = postedAt
    }

    public static var placeholder: WidgetNoticeEntry {
        WidgetNoticeEntry(
            date: .now,
            noticeTitle: "공지사항",
            noticeBody: "최신 공지를 확인해보세요.",
            postedAt: .now
        )
    }
}
