//
//  AttendanceHistoryItem.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

/// 출석 이력 항목 Domain 모델
///
/// `GET /api/v1/attendances/history` 및
/// `GET /api/v1/attendances/challenger/{challengerId}/history` 응답 매핑

import Foundation

public struct AttendanceHistoryItem: Equatable, Identifiable {
    public let id: UUID
    public let attendanceId: Int
    public let scheduleId: Int
    public let scheduleName: String
    public let tags: [String]
    public let scheduledDate: String
    public let startTime: String
    public let endTime: String
    public let status: AttendanceStatus
    public let statusDisplay: String

    public init(
        id: UUID = .init(),
        attendanceId: Int,
        scheduleId: Int,
        scheduleName: String,
        tags: [String],
        scheduledDate: String,
        startTime: String,
        endTime: String,
        status: AttendanceStatus,
        statusDisplay: String
    ) {
        self.id = id
        self.attendanceId = attendanceId
        self.scheduleId = scheduleId
        self.scheduleName = scheduleName
        self.tags = tags
        self.scheduledDate = scheduledDate
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.statusDisplay = statusDisplay
    }
}
