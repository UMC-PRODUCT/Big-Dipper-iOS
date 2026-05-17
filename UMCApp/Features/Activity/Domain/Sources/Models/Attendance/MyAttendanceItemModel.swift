//
//  MyAttendanceItemModel.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import UMCFoundation

// MARK: - MyAttendanceItemModel

/// 내 출석 이력 화면에서 사용하는 표시용 모델
///
/// `Session` 또는 `AttendanceHistoryItem` 으로부터 변환되며,
/// 화면에 노출할 주차/시간/카테고리/상태 정보를 정규화합니다.
public struct MyAttendanceItemModel: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let week: Int
    public let title: String
    public let startTime: Date
    public let endTime: Date
    public let status: MyAttendanceItemStatus
    public let category: ScheduleIconCategory

    public init(
        id: UUID = .init(),
        week: Int,
        title: String,
        startTime: Date,
        endTime: Date,
        status: MyAttendanceItemStatus,
        category: ScheduleIconCategory = .general
    ) {
        self.id = id
        self.week = week
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.category = category
    }

    // MARK: - Computed

    /// 주차 표시 텍스트 (예: "1주차")
    public var weekText: String {
        "\(week)주차"
    }

    /// 시간 범위 텍스트 (예: "14:00 - 18:00")
    public var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - Session Conversion

public extension MyAttendanceItemModel {
    /// Session에서 변환
    /// - Parameters:
    ///   - session: 변환할 세션
    ///   - category: ML 분류 결과 (기본값: .general)
    /// - Note: pending 상태는 nil 반환
    @MainActor
    init?(from session: Session, category: ScheduleIconCategory = .general) {
        guard let itemStatus = MyAttendanceItemStatus(from: session.attendanceStatus) else {
            return nil
        }

        self.id = session.info.id
        self.week = session.info.week
        self.title = session.info.title
        self.startTime = session.info.startTime
        self.endTime = session.info.endTime
        self.status = itemStatus
        self.category = category
    }
}

// MARK: - AttendanceHistoryItem Conversion

public extension MyAttendanceItemModel {
    /// AttendanceHistoryItem에서 변환
    /// - Note: beforeAttendance 상태는 nil 반환
    init?(from item: AttendanceHistoryItem) {
        guard let itemStatus = MyAttendanceItemStatus(from: item.status) else {
            return nil
        }

        self.id = item.id
        self.week = 0
        self.title = item.scheduleName
        self.startTime = Self.parseTimeString(item.startTime)
        var parsedEnd = Self.parseTimeString(item.endTime)
        // FIXME: 자정 넘김 휴리스틱 — 서버가 ISO 8601 datetime 반환 시 제거 (#304)
        if parsedEnd < self.startTime {
            parsedEnd = Calendar.current.date(
                byAdding: .day, value: 1, to: parsedEnd
            ) ?? parsedEnd
        }
        self.endTime = parsedEnd
        self.status = itemStatus
        self.category = .general
    }
}

// MARK: - Internal Helper

extension MyAttendanceItemModel {
    /// "HH:mm:ss" 또는 "HH:mm" → 오늘 Date 변환
    ///
    /// - Note: 외부 모듈 노출이 불필요한 헬퍼이므로 별도 extension 으로 분리해
    ///   default `internal` 접근으로 둡니다. 테스트는 `@testable import` 로 접근.
    static func parseTimeString(_ timeString: String) -> Date {
        if let isoDate = ServerDateTimeConverter.parseUTCDateTime(timeString) {
            return isoDate
        }

        let calendar = Calendar.current
        let now = Date()
        for format in ["HH:mm:ss", "HH:mm"] {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ko_KR")
            if let time = formatter.date(from: timeString) {
                var components = calendar.dateComponents(
                    [.year, .month, .day], from: now
                )
                let timeComponents = calendar.dateComponents(
                    [.hour, .minute, .second], from: time
                )
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                components.second = timeComponents.second
                if let date = calendar.date(from: components) {
                    return date
                }
            }
        }
        return now
    }
}
