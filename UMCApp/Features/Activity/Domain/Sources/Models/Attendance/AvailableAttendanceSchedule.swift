//
//  AvailableAttendanceSchedule.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

/// 출석 가능 일정 Domain 모델
///
/// `GET /api/v1/attendances/available` 응답 매핑

import Foundation

public struct AvailableAttendanceSchedule: Equatable, Identifiable {
    public let id: UUID
    public let scheduleId: Int
    public let scheduleName: String
    public let tags: [String]
    public let startTime: String
    public let endTime: String
    public let sheetId: Int
    public let recordId: Int?
    public let status: AttendanceStatus
    public let statusDisplay: String
    public let locationVerified: Bool

    public init(
        id: UUID = .init(),
        scheduleId: Int,
        scheduleName: String,
        tags: [String],
        startTime: String,
        endTime: String,
        sheetId: Int,
        recordId: Int?,
        status: AttendanceStatus,
        statusDisplay: String,
        locationVerified: Bool
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.scheduleName = scheduleName
        self.tags = tags
        self.startTime = startTime
        self.endTime = endTime
        self.sheetId = sheetId
        self.recordId = recordId
        self.status = status
        self.statusDisplay = statusDisplay
        self.locationVerified = locationVerified
    }
}
