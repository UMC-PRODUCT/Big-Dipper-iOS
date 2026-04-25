//
//  AttendanceRecord.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

/// 출석 기록 상세 Domain 모델
///
/// `GET /api/v1/attendances/{recordId}` 응답 매핑

import Foundation

public struct AttendanceRecord: Equatable, Identifiable {
    public let id: Int
    public let attendanceSheetId: Int
    public let memberId: String
    public let status: AttendanceStatus
    public let memo: String?

    public init(
        id: Int,
        attendanceSheetId: Int,
        memberId: String,
        status: AttendanceStatus,
        memo: String?
    ) {
        self.id = id
        self.attendanceSheetId = attendanceSheetId
        self.memberId = memberId
        self.status = status
        self.memo = memo
    }
}
