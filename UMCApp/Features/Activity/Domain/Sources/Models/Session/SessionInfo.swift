//
//  SessionInfo.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import UMCFoundation

/// 스터디/세미나 세션 정보
///
/// 출석 체크, 일정 표시 등에 사용되는 세션 데이터 모델입니다.
/// - Note: `id`는 SwiftUI List/ForEach용, `sessionId`는 서버 API용
/// - Note: 시각 표현(SF Symbol, 색상)이 필요하면 Presentation 레이어에서
///   `ScheduleIconCategory` 의 `symbol`/`color` extension을 사용합니다.
public struct SessionInfo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sessionId: SessionID
    public let category: ScheduleIconCategory
    public let iconName: String
    public let title: String
    public let week: Int
    public let startTime: Date
    public let endTime: Date
    public let location: Coordinate
    public let isAllDay: Bool

    public init(
        id: UUID = .init(),
        sessionId: SessionID,
        category: ScheduleIconCategory = .general,
        iconName: String,
        title: String,
        week: Int,
        startTime: Date,
        endTime: Date,
        location: Coordinate,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.category = category
        self.iconName = iconName
        self.title = title
        self.week = week
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.isAllDay = isAllDay
    }
}
