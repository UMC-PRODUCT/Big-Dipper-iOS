//
//  MemberAttendanceRecord.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

/// 멤버 출석/활동 기록
///
/// 멤버 상세 화면에서 출석 이력을 표시하기 위한 모델입니다.
/// SessionInfo의 title과 Attendance 정보를 포함합니다.

import Foundation

public struct MemberAttendanceRecord: Identifiable, Equatable {
    public let id: UUID

    /// 세션 제목
    public let sessionTitle: String

    /// 주차 (예: 1, 2, 3...)
    public let week: Int

    /// 출석 정보
    public let status: AttendanceStatus

    public init(
        id: UUID = UUID(),
        sessionTitle: String,
        week: Int,
        status: AttendanceStatus
    ) {
        self.id = id
        self.sessionTitle = sessionTitle
        self.week = week
        self.status = status
    }
}
