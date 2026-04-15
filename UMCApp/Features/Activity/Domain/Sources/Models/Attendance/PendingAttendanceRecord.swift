//
//  PendingAttendanceRecord.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 승인 대기 출석 항목 Domain 모델
///
/// `GET /api/v1/attendances/pending/{scheduleId}` 응답 매핑
public struct PendingAttendanceRecord: Equatable, Identifiable {
    public let id: UUID
    public let attendanceId: Int
    public let memberId: String
    public let memberName: String
    public let nickname: String
    public let profileImageLink: URL?
    public let schoolName: String
    public let status: AttendanceStatus
    public let reason: String?
    public let requestedAt: Date

    public init(
        id: UUID = .init(),
        attendanceId: Int,
        memberId: String,
        memberName: String,
        nickname: String,
        profileImageLink: URL?,
        schoolName: String,
        status: AttendanceStatus,
        reason: String?,
        requestedAt: Date
    ) {
        self.id = id
        self.attendanceId = attendanceId
        self.memberId = memberId
        self.memberName = memberName
        self.nickname = nickname
        self.profileImageLink = profileImageLink
        self.schoolName = schoolName
        self.status = status
        self.reason = reason
        self.requestedAt = requestedAt
    }
}
