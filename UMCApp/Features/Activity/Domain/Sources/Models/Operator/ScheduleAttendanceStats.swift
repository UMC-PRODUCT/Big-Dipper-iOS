//
//  ScheduleAttendanceStats.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 일정별 출석 통계
///
/// `GET /api/v1/schedules` 응답에서 출석 집계 필드만 추출한 모델.
/// `attendanceRate`는 0.0-1.0 범위 (DTO에서 변환 완료).
public struct ScheduleAttendanceStats: Equatable, Sendable {
    public let scheduleId: Int
    public let name: String
    public let date: String
    public let startTime: String
    public let endTime: String
    public let locationName: String
    public let totalCount: Int
    public let presentCount: Int
    public let pendingCount: Int
    public let attendanceRate: Double

    public init(
        scheduleId: Int,
        name: String,
        date: String,
        startTime: String,
        endTime: String,
        locationName: String,
        totalCount: Int,
        presentCount: Int,
        pendingCount: Int,
        attendanceRate: Double
    ) {
        self.scheduleId = scheduleId
        self.name = name
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.locationName = locationName
        self.totalCount = totalCount
        self.presentCount = presentCount
        self.pendingCount = pendingCount
        self.attendanceRate = attendanceRate
    }
}
